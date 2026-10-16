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

> **Supported targets:** this fork only builds `x86_64` on `openwrt-25.12`. Other
> architectures and releases are not published to the feed.

### A. Install From Feed (Recommended)

1. Add Feed

```shell
# only needs to be run once
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/feed.sh | ash
```

2. Install

```shell
# you can install from shell or `Software` menu in LuCI
# for opkg
opkg install momo
opkg install luci-app-momo-core
opkg install luci-i18n-momo-zh-cn
# for apk
apk add momo
apk add luci-app-momo-core
apk add luci-i18n-momo-zh-cn
```

### B. Install From Release

Downloads the packages from the latest GitHub release. No feed is configured and no
signing key is trusted, so this works out of the box.

```shell
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/install-release.sh | ash
```

### C. Install The Packages Directly

Use this if you would rather not add a feed. The packages published with each release
are unsigned, so `--allow-untrusted` is required to skip signature verification.

```shell
# download the packages of the latest release
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/momo-2026.06.03-r2.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-app-momo-1.2.1-r2.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-i18n-momo-zh-cn-26.284.47581~d6a2dbc.apk

# install
apk add --allow-untrusted ./momo-2026.06.03-r2.apk \
                       ./luci-app-momo-1.2.1-r2.apk \
                       ./luci-i18n-momo-zh-cn-26.284.47581~d6a2dbc.apk
```

Dependencies such as `firewall4` and `sing-box` are still fetched from the official
OpenWrt repositories.

## Uninstall & Reset

```shell
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
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
of the upstream one. Keeping the upstream version visible is deliberate: it is
what tells you at a glance which upstream release the changes are based on.

**Every change to a file that ships inside a package must bump `PKG_RELEASE`.**
Without it the package keeps the version a user already has, the package manager
reports it as up to date and skips it, and the new files never reach the device.
This applies to `momo` (`momo.conf`, `files/`) and to `luci-app-momo` (`htdocs/`,
`root/`), independently of each other.

The symptom is an install that reports success but lists no upgrade, for example
`OK: 230.0 MiB in 330 packages` with no `Upgrading ...` line above it.

### Syncing With Upstream

When upstream publishes a new release the fork has to follow it, otherwise the
upstream packages become the newer ones and replace this build:

```shell
# 1. merge or rebase onto the upstream tag
git remote add upstream https://github.com/nikkinikki-org/OpenWrt-momo.git
git fetch upstream
git merge upstream/v1.2.1        # or the tag of the release being synced

# 2. move PKG_VERSION to the upstream version, in both Makefiles
#      momo/Makefile          PKG_VERSION:=2026.06.03
#      luci-app-momo/Makefile PKG_VERSION:=1.2.1

# 3. reset PKG_RELEASE to 2, the first revision on top of that upstream version
```

Step 2 is the one to watch. `1.2.1-r2` outranks `1.2.1-r1`, but upstream's
`1.2.2-r1` outranks `1.2.1-r2` no matter how large `PKG_RELEASE` grows, and
`momo` uses a date based version that moves on every upstream release.

## Compilation

```shell
# add feed
echo "src-git momo https://github.com/580132/OpenWrt-momo.git;main" >> "feeds.conf.default"
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
