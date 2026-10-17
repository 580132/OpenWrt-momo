#!/bin/sh

. "$IPKG_INSTROOT/etc/gg/scripts/include.sh"

# since v1.0.2

section_placeholder=$(uci -q get gg.placeholder); [ -z "$section_placeholder" ] && uci set gg.placeholder="placeholder"

# since v1.1.0

procd=$(uci -q get gg.procd); [ -z "$procd" ] && {
	uci set gg.procd=procd
	uci set gg.procd.fast_reload=$(uci -q get gg.config.fast_reload)
	uci del gg.config.fast_reload
}

# since v1.1.1

# since v1.1.2

config_scheduled_restart_cron=$(uci -q get gg.config.scheduled_restart_cron); [ -z "$config_scheduled_restart_cron" ] && uci rename gg.config.cron_expression="scheduled_restart_cron"

section_log=$(uci -q get gg.log); [ -z "$section_log" ] && {
	uci set gg.log=log
	uci set gg.log.scheduled_clear=1
	uci set gg.log.scheduled_clear_cron="*/5 * * * *"
	uci set gg.log.scheduled_clear_size_limit=1
	uci set gg.log.scheduled_clear_size_limit_unit=MB
}

# since v1.2.1
config_clear_at_stop=$(uci -q get gg.log.clear_at_stop); [ -z "$config_clear_at_stop" ] && uci set gg.log.clear_at_stop=1

# firewall
# gg never touches the firewall; drop the include left by earlier releases and
# the geoip lists the proxy mode used to download
uci -q del firewall.gg
rm -f "/etc/gg/firewall/geoip_cn.nft" "/etc/gg/firewall/geoip6_cn.nft"
rmdir "/etc/gg/firewall" 2> /dev/null

# core only
# the mode is fixed now: the toggle is gone from the ui and the service no
# longer branches on it, so make sure no install is left claiming otherwise
config_core_only=$(uci -q get gg.config.core_only); [ "$config_core_only" != 1 ] && uci set gg.config.core_only=1

# core channel
# the update button follows whatever channel is selected in App Config
config_core_channel=$(uci -q get gg.config.core_channel); [ -z "$config_core_channel" ] && uci set gg.config.core_channel=stable

# core update
# the Core Update table section renders one row per existing uci section of
# its type, so it needs a backing section just like the Status one does
section_core_update=$(uci -q get gg.core_update); [ -z "$section_core_update" ] && uci set gg.core_update=core_update

# subscription stub
# early gg builds shipped an empty 'subscription' section. It renders as a row
# with neither name nor url, so updating it can only fail. Drop it, but keep it
# when it actually holds data.
if [ "$(uci -q get gg.subscription)" = "subscription" ] &&
	[ -z "$(uci -q get gg.subscription.name)" ] &&
	[ -z "$(uci -q get gg.subscription.url)" ]; then
	uci -q del gg.subscription
fi

# commit
uci commit gg

# exit with 0
exit 0
