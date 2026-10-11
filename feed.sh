#!/bin/sh

# Momo's feed

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
feed_url="$repository_url/$branch/$arch/momo"

if [ -x "/bin/opkg" ]; then
	# add key
	echo "add key"
	key_build_pub_file="key-build.pub"
	wget -O "$key_build_pub_file" "$repository_url/key-build.pub"
	opkg-key add "$key_build_pub_file"
	rm -f "$key_build_pub_file"
	# add feed
	echo "add feed"
	if grep -q momo /etc/opkg/customfeeds.conf; then
		sed -i '/momo/d' /etc/opkg/customfeeds.conf
	fi
	echo "src/gz momo $feed_url" >> /etc/opkg/customfeeds.conf
	# update feeds
	echo "update feeds"
	opkg update
elif [ -x "/usr/bin/apk" ]; then
	# add key
	echo "add key"
	wget -O "/etc/apk/keys/momo.pem" "$repository_url/public-key.pem"
	# add feed
	echo "add feed"
	if grep -q momo /etc/apk/repositories.d/customfeeds.list; then
		sed -i '/momo/d' /etc/apk/repositories.d/customfeeds.list
	fi
	echo "$feed_url/packages.adb" >> /etc/apk/repositories.d/customfeeds.list
	# update feeds
	echo "update feeds"
	apk update
fi

echo "success"
