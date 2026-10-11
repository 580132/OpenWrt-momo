![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-momo/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

English | [中文](README.zh.md)

# Momo

Transparent Proxy with sing-box on OpenWrt.

## Prerequisites

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## Feature

- Transparent Proxy (Redirect/TPROXY/TUN, IPv4 and/or IPv6)
- Access Control
- Profile Editor
- Scheduled Restart
- Core Update (stable / preview / rollback)

## Core Update

`App Config` -> `Core Update` can update the sing-box core in place.

- **Check for Updates** - reads the latest stable and preview tags from the sing-box releases.
- **Update To Latest Stable** / **Update To Latest Preview** - downloads the official sing-box
  OpenWrt package (`.ipk` / `.apk`) built for this router's target architecture and installs it
  with `opkg` / `apk`, then restarts the service. Preview releases are prereleases and may be unstable.
- **Rollback Core** - reinstalls the version the core was running before the last update.

The update runs in the background and shows its progress in a dialog. Every step is also written
to the app log, and the `opkg` / `apk` output is appended there for troubleshooting.

Notes:

- The core is installed as the regular `sing-box` package, so `opkg upgrade sing-box` / `apk` will
  still restore the packaged version if you prefer.
- At least 128 MiB of free space on the firmware partition is required, plus room for the download
  in `/tmp`. The available space is checked before anything is downloaded.
- The same can be done from the shell:

```
# update to the latest stable release
/etc/init.d/momo update_core stable
# update to the latest preview release
/etc/init.d/momo update_core preview
# roll back to the previous version
/etc/init.d/momo rollback_core
```

## Install & Update

### A. Install From Feed (Recommended)

1. Add Feed

```shell
# only needs to be run once
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/feed.sh | ash
```

2. Install

```shell
# you can install from shell or `Software` menu in LuCI
# for opkg
opkg install momo
opkg install luci-app-momo
opkg install luci-i18n-momo-zh-cn
# for apk
apk add momo
apk add luci-app-momo
apk add luci-i18n-momo-zh-cn
```

### B. Install From Release

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/install.sh | ash
```

## Uninstall & Reset

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
```

## How To Use

See [Wiki](https://github.com/nikkinikki-org/OpenWrt-momo/wiki)

## How does it work
 
1. Run sing-box.
2. Set scheduled restart.
3. Get neccesarry param from profile.
4. Set ip rule/route.
5. Generate firewall and apply it.

Note that the steps above may change base on config.

## Versioning

`PKG_VERSION` tracks the upstream version, `PKG_RELEASE` is this fork's own revision
number and is incremented on every release.

```
luci-app-momo  1.2.1-r2   (PKG_VERSION:=1.2.1, PKG_RELEASE:=2)
momo           2026.06.03-r2
```

`-rN` sorts above the upstream `-r1`, so a package manager picks this build up instead
of the upstream one. Note that it only holds while `PKG_VERSION` stays the same: once
upstream publishes a new version, bump `PKG_VERSION` to match it and restart the
release number at `2`.

## Compilation

```shell
# add feed
echo "src-git momo https://github.com/nikkinikki-org/OpenWrt-momo.git;main" >> "feeds.conf.default"
# update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# make package
make package/luci-app-momo/compile
```

The package files will be found under `bin/packages/your_architecture/momo`.

## Dependencies

- ca-bundle
- curl
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- sing-box >= 1.12

## Contributors

[![Contributors](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-momo)](https://github.com/nikkinikki-org/OpenWrt-momo/graphs/contributors)
