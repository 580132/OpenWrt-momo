#!/bin/sh

# uninstall

if [ -x "/bin/opkg" ]; then
	opkg list-installed luci-i18n-gg-* | cut -d ' ' -f 1 | xargs opkg remove
	opkg remove luci-app-gg
	opkg remove gg
elif [ -x "/usr/bin/apk" ]; then
	apk list --installed --manifest luci-i18n-gg-* | cut -d ' ' -f 1 | xargs apk del
	apk del luci-app-gg
	apk del gg
fi
# remove config
rm -f /etc/config/gg
# remove files
rm -rf /etc/gg
# remove log
rm -rf /var/log/gg
# remove temp
rm -rf /var/run/gg
# remove feed
repository_url="https://580132.github.io/OpenWrt-momo"
if [ -x "/bin/opkg" ]; then
	if grep -q '^src/gz gg ' /etc/opkg/customfeeds.conf; then
		sed -i '/^src\/gz gg /d' /etc/opkg/customfeeds.conf
	fi
	wget -O "key-build.pub" "$repository_url/key-build.pub"
	opkg-key remove key-build.pub
	rm -f key-build.pub
elif [ -x "/usr/bin/apk" ]; then
	if grep -q '/gg/packages\.adb' /etc/apk/repositories.d/customfeeds.list; then
		sed -i '\#/gg/packages\.adb#d' /etc/apk/repositories.d/customfeeds.list
	fi
	rm -f /etc/apk/keys/gg.pem
fi
