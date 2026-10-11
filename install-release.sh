#!/bin/sh

# Momo's standalone installer
#
# Downloads the packages straight from the GitHub release and installs them.
# No feed is configured and no signing key is trusted, which is why the
# packages have to be installed with --allow-untrusted.

# check env
if [[ ! -x "/bin/opkg" && ! -x "/usr/bin/apk" || ! -x "/sbin/fw4" ]]; then
	echo "only supports OpenWrt build with firewall4!"
	exit 1
fi

# include openwrt_release
. /etc/openwrt_release

# get branch/arch
arch="$DISTRIB_ARCH"
branch=
case "$DISTRIB_RELEASE" in
	*"25.12"*)
		branch="openwrt-25.12"
		;;
	*)
		echo "unsupported release: $DISTRIB_RELEASE"
		exit 1
		;;
esac

# supported targets
# keep in sync with the matrix in .github/workflows/release-unsigned.yml
supported_branch="openwrt-25.12"
supported_arch="x86_64"

if [ "$branch" != "$supported_branch" ] || [ "$arch" != "$supported_arch" ]; then
	echo "no build available for $branch/$arch"
	echo "this fork only builds $supported_branch/$supported_arch"
	exit 1
fi

# repository
repository="580132/OpenWrt-momo"
releases_url="https://github.com/$repository/releases"

# package extension
if [ -x "/bin/opkg" ]; then
	extension="ipk"
else
	extension="apk"
fi

# work dir
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# get latest tag
echo "get latest release"
tag=$(curl -s -f -m 60 --connect-timeout 15 -L -o /dev/null -w '%{url_effective}' "$releases_url/latest" 2> /dev/null)
tag="${tag##*/tag/}"

# a failed request leaves the full url in place, which would slip through a
# comparison against "latest", so match on the shape a real tag has
case "$tag" in
	v*)
		echo "latest release: $tag"
		;;
	*)
		echo "failed to determine the latest release"
		exit 1
		;;
esac

# list assets
# the expanded_assets page is used instead of the api so that no rate limit applies
echo "get packages"
assets=$(curl -s -f -m 60 --connect-timeout 15 -L "$releases_url/expanded_assets/$tag" 2> /dev/null \
	| grep -o "/$repository/releases/download/[^\"]*\.$extension" \
	| sort -u)

if [ -z "$assets" ]; then
	echo "no $extension package found in release $tag"
	exit 1
fi

# get languages
echo "get languages"
if [ "$extension" = "ipk" ]; then
	languages=$(opkg list-installed luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
else
	languages=$(apk list --installed --manifest luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
fi

# download the packages matching the given name prefix
# $1: file name prefix
download_package() {
	local prefix="$1"
	local path
	path=$(echo "$assets" | grep -m 1 "/download/$tag/$prefix")
	if [ -z "$path" ]; then
		echo "package not found in release $tag: $prefix*$extension"
		exit 1
	fi
	local file="${path##*/}"
	echo "download $file"
	if ! curl -s -f -m 600 --connect-timeout 15 --retry 3 -L -o "$work_dir/$file" "https://github.com$path" > /dev/null 2>&1; then
		echo "failed to download $file"
		exit 1
	fi
}

# download
echo "download packages"
download_package "momo-"
download_package "luci-app-momo-"
for lang in $languages; do
	download_package "luci-i18n-momo-${lang}-"
done

# install
echo "install packages"
packages=$(ls "$work_dir")
if [ "$extension" = "ipk" ]; then
	# shellcheck disable=SC2086
	opkg install --force-depends --force-reinstall $(for p in $packages; do echo "$work_dir/$p"; done)
else
	# shellcheck disable=SC2086
	apk add --allow-untrusted $(for p in $packages; do echo "$work_dir/$p"; done)
fi

echo "success"
