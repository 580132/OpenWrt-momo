#!/bin/sh

. "$IPKG_INSTROOT/etc/gg/scripts/include.sh"

uci -q batch <<-EOF > /dev/null
	del firewall.gg
	set firewall.gg=include
	set firewall.gg.type=script
	set firewall.gg.path=$FIREWALL_INCLUDE_SH
	set firewall.gg.fw4_compatible=1
	commit firewall
EOF
