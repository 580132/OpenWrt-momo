#!/bin/sh

. "$IPKG_INSTROOT/etc/momo/scripts/include.sh"

## constants

CORE_REPO="SagerNet/sing-box"
CORE_API_BASE="https://api.github.com/repos/$CORE_REPO"
CORE_RELEASES_URL="https://github.com/$CORE_REPO/releases"
CORE_DOWNLOAD_BASE="https://github.com/$CORE_REPO/releases/download"

# The check runs inside a single rpcd call, and LuCI abandons rpc after 20
# seconds by default, so these are kept far below the generous timeouts the
# background update job uses.
CORE_CHECK_MAX_TIME=5
CORE_CHECK_CONNECT_TIME=3

# minimum free space (in KiB) required on the overlay filesystem to install a new core
CORE_MIN_FREE_SPACE=131072

## helpers

step() {
	echo "$1" >> "$CORE_UPDATE_STATUS_PATH"
	log "Core" "$1"
}

fail() {
	echo "Error: $1" >> "$CORE_UPDATE_STATUS_PATH"
	log "Core" "Error: $1"
}

get_package_manager() {
	# apk is checked first on purpose. OpenWrt since 25.12 ships apk, and opkg
	# survives only as a compatibility shim whose package database is empty, so
	# picking opkg there installs against a database that knows nothing about
	# the package being installed.
	if command -v apk > /dev/null 2>&1; then
		echo "apk"
	elif command -v opkg > /dev/null 2>&1; then
		echo "opkg"
	else
		echo ""
	fi
}

get_package_extension() {
	case "$(get_package_manager)" in
		opkg) echo "ipk" ;;
		apk) echo "apk" ;;
		*) echo "" ;;
	esac
}

# The sing-box release assets are named after the OpenWrt target architecture,
# which is exactly what /etc/openwrt_release reports as DISTRIB_ARCH.
get_target_arch() {
	local arch
	arch=$(sed -n "s/^DISTRIB_ARCH='\(.*\)'\$/\1/p" /etc/openwrt_release 2> /dev/null)
	if [ -z "$arch" ]; then
		arch=$(sed -n "s/^DISTRIB_TARGET_ARCH='\(.*\)'\$/\1/p" /etc/openwrt_release 2> /dev/null)
	fi
	if [ -z "$arch" ]; then
		case "$(get_package_manager)" in
			opkg) arch=$(opkg print-architecture 2> /dev/null) ;;
			apk) arch=$(apk --print-arch 2> /dev/null) ;;
		esac
	fi
	echo "$arch"
}

get_current_version() {
	local version
	version=$("$CORE_PATH" version 2> /dev/null | grep -m 1 "sing-box version" | cut -d " " -f 3)
	echo "$version"
}

get_previous_version() {
	if [ -f "$CORE_PREVIOUS_VERSION_PATH" ]; then
		cat "$CORE_PREVIOUS_VERSION_PATH" 2> /dev/null
	fi
}

set_previous_version() {
	mkdir -p "$CORE_DIR"
	echo "$1" > "$CORE_PREVIOUS_VERSION_PATH"
}

get_free_space() {
	df -k "$1" 2> /dev/null | awk 'NR == 2 { print $4 }'
}

# $1: channel (stable|preview), $2: json file to write
core_api_get() {
	curl -s -f -m 60 --connect-timeout 15 --retry 2 \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		-o "$2" "$1" > /dev/null 2>&1
}

# prints the tag of the latest release of the given channel
# $1: channel (stable|preview), $2: directory used to store the api responses
get_latest_tag() {
	local channel="$1"
	local work_dir="$2"
	local stable_path="$work_dir/release.json"
	local list_path="$work_dir/releases.json"
	if [ "$channel" = "stable" ]; then
		core_api_get "$CORE_API_BASE/releases/latest" "$stable_path" || return 1
		ucode -S -e "
			import { readfile } from 'fs';
			let release = json(readfile('$stable_path'));
			print(release['tag_name']);
		"
	else
		core_api_get "$CORE_API_BASE/releases?per_page=20" "$list_path" || return 1
		ucode -S -e "
			import { readfile } from 'fs';
			let releases = json(readfile('$list_path'));
			for (let release in releases) {
				if (release['prerelease'] == true && release['draft'] != true) {
					print(release['tag_name']);
					break;
				}
			}
		"
	fi
}

# prints the size (in bytes) of the given asset, or nothing if it is missing
# $1: json file, $2: asset name
get_asset_size() {
	ucode -S -e "
		import { readfile } from 'fs';
		let release = json(readfile('$1'));
		for (let asset in release['assets']) {
			if (asset['name'] == '$2') {
				print(asset['size']);
				break;
			}
		}
	"
}

# returns non zero when there is not enough room to run an update
# $1: size of the package to download (in bytes)
check_free_space() {
	local package_size_kb; package_size_kb=$(( $1 / 1024 + 1 ))
	local required_kb; required_kb=$(( package_size_kb + 16384 ))
	local temp_free overlay_free
	temp_free=$(get_free_space "$TEMP_DIR")
	overlay_free=$(get_free_space "$HOME_DIR")
	if [ -z "$temp_free" ] || [ -z "$overlay_free" ]; then
		return 0
	fi
	if [ "$temp_free" -lt "$required_kb" ]; then
		fail "Not enough space in $TEMP_DIR, $temp_free KiB available but at least $required_kb KiB needed."
		return 1
	fi
	if [ "$overlay_free" -lt "$CORE_MIN_FREE_SPACE" ]; then
		fail "Not enough space on the firmware partition, $overlay_free KiB available but at least $CORE_MIN_FREE_SPACE KiB needed."
		return 1
	fi
	return 0
}

install_package() {
	local package_manager="$1"
	local package_path="$2"
	local log_path="$CORE_UPDATE_DIR/install.log"
	local result=0
	case "$package_manager" in
		opkg)
			opkg install --force-reinstall --force-depends "$package_path" > "$log_path" 2>&1 || result=1
		;;
		apk)
			apk add --allow-untrusted --force-overwrite --force-missing-repositories "$package_path" > "$log_path" 2>&1 || result=1
		;;
		*)
			result=1
		;;
	esac
	sed "s/^/[Core] /" "$log_path" >> "$APP_LOG_PATH" 2> /dev/null
	return $result
}

restart_service() {
	if /etc/init.d/momo status > /dev/null 2>&1; then
		step "Restarting the service..."
		if /etc/init.d/momo restart > /dev/null 2>&1; then
			step "Service restarted."
		else
			fail "Failed to restart the service, please check the app log."
			return 1
		fi
	else
		step "The service is not running, skip restarting."
	fi
	return 0
}

## lock

# $1: --locked when the lock is already held by the parent process
acquire_lock() {
	if [ "$1" = "--locked" ]; then
		return 0
	fi
	if mkdir "$CORE_UPDATE_LOCK_PATH" 2> /dev/null; then
		return 0
	fi
	local pid
	pid=$(cat "$CORE_UPDATE_LOCK_PATH/pid" 2> /dev/null)
	if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
		log "Core" "Removing a stale core update lock."
		rm -rf "$CORE_UPDATE_LOCK_PATH"
		if mkdir "$CORE_UPDATE_LOCK_PATH" 2> /dev/null; then
			return 0
		fi
	fi
	return 1
}

release_lock() {
	rm -rf "$CORE_UPDATE_LOCK_PATH"
}

## actions

# downloads and installs the given version of the core
# $1: version without the leading v
core_install_version() {
	local version="$1"
	local package_manager extension target_arch
	package_manager=$(get_package_manager)
	if [ -z "$package_manager" ]; then
		fail "Neither opkg nor apk was found on this system."
		return 1
	fi
	extension=$(get_package_extension)
	target_arch=$(get_target_arch)
	if [ -z "$target_arch" ]; then
		fail "Failed to detect the OpenWrt target architecture."
		return 1
	fi
	local current_version
	current_version=$(get_current_version)
	step "Package manager: $package_manager."
	step "Target architecture: $target_arch."
	step "Current version: ${current_version:-unknown}."
	if [ "$current_version" = "$version" ]; then
		step "The core is already at version $version."
		return 0
	fi
	# fetch release info
	local tag; tag="v$version"
	local release_path="$CORE_UPDATE_DIR/release.json"
	step "Fetching release information of $tag..."
	if ! core_api_get "$CORE_API_BASE/releases/tags/$tag" "$release_path"; then
		fail "Failed to fetch the release information of $tag from GitHub."
		return 1
	fi
	# locate the package
	local asset_name; asset_name="sing-box_${version}_openwrt_${target_arch}.${extension}"
	local asset_size; asset_size=$(get_asset_size "$release_path" "$asset_name")
	if [ -z "$asset_size" ]; then
		fail "The release $tag does not provide a package for $target_arch ($extension)."
		return 1
	fi
	step "Package: $asset_name ($(format_filesize "$asset_size"))."
	# check the available space
	check_free_space "$asset_size" || return 1
	# download
	# keep the real asset name, opkg parses the architecture out of the file
	# name and rejects anything it cannot parse
	local package_path="$CORE_UPDATE_DIR/$asset_name"
	local download_url="$CORE_DOWNLOAD_BASE/$tag/$asset_name"
	step "Downloading..."
	if ! curl -s -f -m 1800 --connect-timeout 15 --retry 3 -L -o "$package_path" "$download_url" > /dev/null 2>&1; then
		rm -f "$package_path"
		fail "Failed to download $asset_name."
		return 1
	fi
	step "Download completed."
	# install
	step "Installing..."
	if ! install_package "$package_manager" "$package_path"; then
		rm -f "$package_path"
		fail "Failed to install the package, please check the app log for details."
		return 1
	fi
	rm -f "$package_path"
	# verify
	local new_version
	new_version=$(get_current_version)
	if [ "$new_version" != "$version" ]; then
		fail "Verification failed, expected version $version but got ${new_version:-unknown}."
		return 1
	fi
	step "The core has been updated to $new_version."
	# remember the previous version so it can be restored later
	if [ -n "$current_version" ]; then
		set_previous_version "$current_version"
		step "Previous version: $current_version."
	fi
	# restart
	restart_service
}

# updates the core to the latest release of the given channel
# $1: channel (stable|preview)
core_update() {
	local channel="$1"
	case "$channel" in
		stable | preview) ;;
		*)
			fail "Invalid channel: $channel."
			return 1
		;;
	esac
	step "Looking for the latest $channel release..."
	local tag version
	tag=$(get_latest_tag "$channel" "$CORE_UPDATE_DIR")
	if [ -z "$tag" ]; then
		fail "Failed to fetch the latest $channel release from GitHub, please check the network connection."
		return 1
	fi
	version="${tag#v}"
	step "Latest $channel release: $version."
	core_install_version "$version"
}

# reinstalls the version the core was running before the last update
core_rollback() {
	local version
	version=$(get_previous_version)
	if [ -z "$version" ]; then
		fail "There is no previous version to roll back to."
		return 1
	fi
	step "Rolling back to version $version..."
	core_install_version "$version"
}

# prints local information about the core as json
core_info() {
	local package_manager extension target_arch current_version previous_version
	package_manager=$(get_package_manager)
	extension=$(get_package_extension)
	target_arch=$(get_target_arch)
	current_version=$(get_current_version)
	previous_version=$(get_previous_version)
	printf '{"package_manager":"%s","package_extension":"%s","target_arch":"%s","current_version":"%s","previous_version":"%s"}\n' \
		"$package_manager" "$extension" "$target_arch" "$current_version" "$previous_version"
}

# prints the version of the latest stable sing-box release
# /releases/latest redirects to the newest non prerelease, which avoids the
# api host entirely and is far more likely to be reachable
get_latest_stable_tag() {
	local url
	url=$(curl -s -f -m $CORE_CHECK_MAX_TIME --connect-timeout $CORE_CHECK_CONNECT_TIME -L -o /dev/null -w '%{url_effective}' "$CORE_RELEASES_URL/latest" 2> /dev/null)
	url="${url##*/tag/}"
	case "$url" in
		v*) echo "${url#v}" ;;
		*) ;;
	esac
}

# prints the version of the latest preview sing-box release
# the atom feed lists recent releases newest first, so the first entry tagged
# as a prerelease is the newest one
get_latest_preview_tag() {
	curl -s -f -m $CORE_CHECK_MAX_TIME --connect-timeout $CORE_CHECK_CONNECT_TIME -L "$CORE_RELEASES_URL.atom" 2> /dev/null \
		| grep -o "$CORE_RELEASES_URL/tag/v[^\"<]*" \
		| grep -m 1 -E -- '-(alpha|beta|rc)' \
		| sed "s#.*/tag/v##"
}

# prints the latest tag of each channel as json
core_check() {
	local stable_tag preview_tag
	stable_tag=$(get_latest_stable_tag)
	preview_tag=$(get_latest_preview_tag)
	printf '{"stable":"%s","preview":"%s"}\n' "$stable_tag" "$preview_tag"
}

## entry

prepare_core_update() {
	prepare_files
	rm -rf "$CORE_UPDATE_DIR"
	mkdir -p "$CORE_UPDATE_DIR"
	rm -f "$CORE_UPDATE_RESULT_PATH"
}

finish_core_update() {
	if [ "$1" = 0 ]; then
		echo "success" > "$CORE_UPDATE_RESULT_PATH"
	else
		echo "failure" > "$CORE_UPDATE_RESULT_PATH"
	fi
}

# runs an action in the background and returns immediately
# $1: action, rest: arguments of the action
start_core_update() {
	local action="$1"
	shift
	prepare_core_update
	if ! acquire_lock; then
		log "Core" "Another core update is already running."
		return 1
	fi
	# nohup is not part of every busybox build on OpenWrt, so detach without
	# it; a signal set to be ignored here survives the exec of the worker
	trap '' HUP
	"$0" "$action" "$@" --locked < /dev/null > /dev/null 2>&1 &
	local worker_pid="$!"
	echo "$worker_pid" > "$CORE_UPDATE_LOCK_PATH/pid"
	# the worker has to be confirmed alive before reporting success, otherwise
	# a spawn that silently fails leaves the lock held and the caller polling a
	# job that will never run and never release it
	sleep 1
	if ! kill -0 "$worker_pid" 2> /dev/null && [ ! -f "$CORE_UPDATE_RESULT_PATH" ]; then
		release_lock
		log "Core" "Failed to start the core update worker."
		return 1
	fi
	return 0
}

case "$1" in
	update)
		shift
		channel="$1"
		prepare_core_update
		if ! acquire_lock "$2"; then
			exit 1
		fi
		core_update "$channel"
		result=$?
		finish_core_update $result
		release_lock
		exit $result
	;;
	rollback)
		prepare_core_update
		if ! acquire_lock "$2"; then
			exit 1
		fi
		core_rollback
		result=$?
		finish_core_update $result
		release_lock
		exit $result
	;;
	start)
		shift
		start_core_update "$@"
		exit $?
	;;
	info)
		core_info
		exit 0
	;;
	check)
		core_check
		exit 0
	;;
	*)
		echo "Usage: $0 {start {update <stable|preview>|rollback} | update <stable|preview> | rollback | info | check}" >&2
		exit 1
	;;
esac
