#!/bin/sh

. "$IPKG_INSTROOT/etc/gg/scripts/include.sh"

# since v1.0.2

section_placeholder=$(uci -q get gg.placeholder); [ -z "$section_placeholder" ] && uci set gg.placeholder="placeholder"

# since v1.1.0

proxy_bypass_china_mainland_ip=$(uci -q get gg.proxy.bypass_china_mainland_ip)
proxy_bypass_china_mainland_ip6=$(uci -q get gg.proxy.bypass_china_mainland_ip6)
[ -z "$proxy_bypass_china_mainland_ip6" ] && uci set gg.proxy.bypass_china_mainland_ip6=$proxy_bypass_china_mainland_ip

routing_tproxy_fw_mask=$(uci -q get gg.routing.tproxy_fw_mask); [ -z "$routing_tproxy_fw_mask" ] && uci set gg.routing.tproxy_fw_mask=0xFF
routing_tun_fw_mask=$(uci -q get gg.routing.tun_fw_mask); [ -z "$routing_tun_fw_mask" ] && uci set gg.routing.tun_fw_mask=0xFF

procd=$(uci -q get gg.procd); [ -z "$procd" ] && {
	uci set gg.procd=procd
	uci set gg.procd.fast_reload=$(uci -q get gg.config.fast_reload)
	uci del gg.config.fast_reload
}

# since v1.1.1

dummy_device=$(uci -q get gg.routing.dummy_device); [ -z "$dummy_device" ] && uci set gg.routing.dummy_device=gg-dummy

# since v1.1.2

config_scheduled_restart_cron=$(uci -q get gg.config.scheduled_restart_cron); [ -z "$config_scheduled_restart_cron" ] && uci rename gg.config.cron_expression="scheduled_restart_cron"

section_log=$(uci -q get gg.log); [ -z "$section_log" ] && {
	uci set gg.log=log
	uci set gg.log.scheduled_clear=1
	uci set gg.log.scheduled_clear_cron="*/5 * * * *"
	uci set gg.log.scheduled_clear_size_limit=1
	uci set gg.log.scheduled_clear_size_limit_unit=MB
}

section_mixin=$(uci -q get gg.mixin); [ -z "$section_mixin" ] && {
	uci set gg.mixin=mixin
	uci set gg.mixin.log_disabled='0'
	uci set gg.mixin.log_level='info'
	uci set gg.mixin.log_timestamp='1'
	uci set gg.mixin.dns_independent_cache='1'
	uci set gg.mixin.dns_reverse_mapping='1'
	uci set gg.mixin.cache_enabled='1'
	uci set gg.mixin.cache_store_fakeip='1'
	uci set gg.mixin.cache_store_rdrc='1'
	uci set gg.mixin.external_control_ui_path='ui'
	uci set gg.mixin.external_control_ui_download_url='https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip'
}

# since v1.2.1
config_clear_at_stop=$(uci -q get gg.log.clear_at_stop); [ -z "$config_clear_at_stop" ] && uci set gg.log.clear_at_stop=1

# firewall
# gg never touches the firewall; drop the include left by earlier releases
uci -q del firewall.gg

# core channel
# the update button follows whatever channel is selected in App Config
config_core_channel=$(uci -q get gg.config.core_channel); [ -z "$config_core_channel" ] && uci set gg.config.core_channel=stable

# core update
# the Core Update table section renders one row per existing uci section of
# its type, so it needs a backing section just like the Status one does
section_core_update=$(uci -q get gg.core_update); [ -z "$section_core_update" ] && uci set gg.core_update=core_update

# commit
uci commit gg

# exit with 0
exit 0
