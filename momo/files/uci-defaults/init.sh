#!/bin/sh

. "$IPKG_INSTROOT/etc/gg/scripts/include.sh"

# check gg.config.init
init=$(uci -q get gg.config.init); [ -z "$init" ] && return

# generate random string for api secret and authentication password
random=$(awk 'BEGIN{srand(); printf "%06d", int(rand() * 1000000)}')

# set gg.mixin.api_secret
uci set gg.mixin.external_control_api_secret="$random"

# remove gg.config.init
uci del gg.config.init

# commit
uci commit gg

# exit with 0
exit 0
