#!/bin/sh

# GG's installer

# check env
if [ ! -x "/bin/opkg" ] && [ ! -x "/usr/bin/apk" ]; then
	echo "only supports OpenWrt with opkg or apk!"
	exit 1
fi

# include openwrt_release
. /etc/openwrt_release

# get branch/arch
arch="$DISTRIB_ARCH"
branch=
case "$DISTRIB_RELEASE" in
	*"24.10"*)
		branch="openwrt-24.10"
		;;
	*"25.12"*)
		branch="openwrt-25.12"
		;;
	"SNAPSHOT")
		branch="SNAPSHOT"
		;;
	*)
		echo "unsupported release: $DISTRIB_RELEASE"
		exit 1
		;;
esac

# supported targets
# keep in sync with the matrix in .github/workflows/release-packages.yml
supported_branch="openwrt-25.12"
supported_arch="x86_64"

if [ "$branch" != "$supported_branch" ] || [ "$arch" != "$supported_arch" ]; then
	echo "no build available for $branch/$arch"
	echo "this fork only builds $supported_branch/$supported_arch"
	exit 1
fi

# feed url
repository_url="https://580132.github.io/OpenWrt-momo"
feed_url="$repository_url/$branch/$arch/gg"

if [ -x "/bin/opkg" ]; then
	# update feeds
	echo "update feeds"
	opkg update
	# get languages
	echo "get languages"
	languages=$(opkg list-installed luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
	# get latest version
	echo "get latest version"
	wget -O gg.version $feed_url/index.json
	# install ipks
	echo "install ipks"
	eval "$(jsonfilter -i gg.version -e "gg_version=@['packages']['gg']" -e "luci_app_gg_version=@['packages']['luci-app-gg']")"
	opkg install "$feed_url/gg_${gg_version}_${arch}.ipk"
	opkg install "$feed_url/luci-app-gg_${luci_app_gg_version}_all.ipk"
	for lang in $languages; do
		lang_version=$(jsonfilter -i gg.version -e "@['packages']['luci-i18n-gg-${lang}']")
		opkg install "$feed_url/luci-i18n-gg-${lang}_${lang_version}_all.ipk"
	done
	
	rm -f gg.version
elif [ -x "/usr/bin/apk" ]; then
	# update feeds
	echo "update feeds"
	apk update
	# get languages
	echo "get languages"
	languages=$(apk list --installed --manifest luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
	# install apks from remote repository
	echo "install apks from remote repository"
	apk add --allow-untrusted -X $feed_url/packages.adb gg luci-app-gg
	for lang in $languages; do
		apk add --allow-untrusted -X $feed_url/packages.adb "luci-i18n-gg-${lang}"
	done
fi

echo "success" 
