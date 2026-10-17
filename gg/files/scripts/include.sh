#!/bin/sh

. "$IPKG_INSTROOT/usr/share/libubox/jshn.sh"

# paths

## home
HOME_DIR="/etc/gg"
PROFILES_DIR="$HOME_DIR/profiles"
SUBSCRIPTIONS_DIR="$HOME_DIR/subscriptions"

## run
RUN_DIR="$HOME_DIR/run"
RUN_PROFILE_PATH="$RUN_DIR/config.json"

## ucode
UCODE_DIR="$HOME_DIR/ucode"
INCLUDE_UC="$UCODE_DIR/include.uc"

## scripts
SH_DIR="$HOME_DIR/scripts"
INCLUDE_SH="$SH_DIR/include.sh"
DEBUG_SH="$SH_DIR/debug.sh"
UPDATE_CORE_SH="$SH_DIR/update_core.sh"

## core
CORE_PATH="/usr/bin/sing-box"
CORE_DIR="$HOME_DIR/core"
CORE_PREVIOUS_VERSION_PATH="$CORE_DIR/previous_version"

## log
LOG_DIR="/var/log/gg"
APP_LOG_PATH="$LOG_DIR/app.log"
CORE_LOG_PATH="$LOG_DIR/core.log"
DEBUG_LOG_PATH="$LOG_DIR/debug.log"

## temp
TEMP_DIR="/var/run/gg"
PID_FILE_PATH="$TEMP_DIR/gg.pid"
STARTED_FLAG_PATH="$TEMP_DIR/started.flag"
CORE_UPDATE_DIR="$TEMP_DIR/core_update"
CORE_UPDATE_STATUS_PATH="$CORE_UPDATE_DIR/status"
CORE_UPDATE_RESULT_PATH="$CORE_UPDATE_DIR/result"
CORE_UPDATE_LOCK_PATH="$TEMP_DIR/core_update.lock"

# functions
get_paths() {
	json_init

	json_add_string home_dir "$HOME_DIR"
	json_add_string profiles_dir "$PROFILES_DIR"
	json_add_string subscriptions_dir "$SUBSCRIPTIONS_DIR"

	json_add_string run_dir "$RUN_DIR"
	json_add_string run_profile_path "$RUN_PROFILE_PATH"

	json_add_string ucode_dir "$UCODE_DIR"
	json_add_string include_uc "$INCLUDE_UC"

	json_add_string sh_dir "$SH_DIR"
	json_add_string include_sh "$INCLUDE_SH"
	json_add_string debug_sh "$DEBUG_SH"
	json_add_string update_core_sh "$UPDATE_CORE_SH"

	json_add_string core_path "$CORE_PATH"
	json_add_string core_dir "$CORE_DIR"
	json_add_string core_previous_version_path "$CORE_PREVIOUS_VERSION_PATH"

	json_add_string log_dir "$LOG_DIR"
	json_add_string app_log_path "$APP_LOG_PATH"
	json_add_string core_log_path "$CORE_LOG_PATH"
	json_add_string debug_log_path "$DEBUG_LOG_PATH"

	json_add_string temp_dir "$TEMP_DIR"
	json_add_string pid_file_path "$PID_FILE_PATH"
	json_add_string started_flag_path "$STARTED_FLAG_PATH"
	json_add_string core_update_dir "$CORE_UPDATE_DIR"
	json_add_string core_update_status_path "$CORE_UPDATE_STATUS_PATH"
	json_add_string core_update_result_path "$CORE_UPDATE_RESULT_PATH"
	json_add_string core_update_lock_path "$CORE_UPDATE_LOCK_PATH"

	json_dump

	json_cleanup
}

format_filesize() {
	local b; b=1
	local kb; kb=$((b * 1024))
	local mb; mb=$((kb * 1024))
	local gb; gb=$((mb * 1024))
	local tb; tb=$((gb * 1024))
	local pb; pb=$((tb * 1024))
	local size; size=$1
	if [ -n "$size" ]; then
		if [ "$size" -lt "$kb" ]; then
			echo "$(awk "BEGIN {print $size / $b}") B"
		elif [ "$size" -lt "$mb" ]; then
			echo "$(awk "BEGIN {print $size / $kb}") KB"
		elif [ "$size" -lt "$gb" ]; then
			echo "$(awk "BEGIN {print $size / $mb}") MB"
		elif [ "$size" -lt "$tb" ]; then
			echo "$(awk "BEGIN {print $size / $gb}") GB"
		elif [ "$size" -lt "$pb" ]; then
			echo "$(awk "BEGIN {print $size / $tb}") TB"
		else
			echo "$(awk "BEGIN {print $size / $pb}") PB"
		fi
	fi
}

prepare_files() {
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p "$LOG_DIR"
	fi
	if [ ! -f "$APP_LOG_PATH" ]; then
		touch "$APP_LOG_PATH"
	fi
	if [ ! -f "$CORE_LOG_PATH" ]; then
		touch "$CORE_LOG_PATH"
	fi
	if [ ! -d "$TEMP_DIR" ]; then
		mkdir -p "$TEMP_DIR"
	fi
	if [ ! -d "$CORE_DIR" ]; then
		mkdir -p "$CORE_DIR"
	fi
}

log() {
	echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$1] $2" >> "$APP_LOG_PATH"
}
