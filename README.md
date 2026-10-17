![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-momo/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

English | [中文](README.zh.md)

# GG

Runs the sing-box core on OpenWrt: subscriptions and core updates, nothing else.

## Prerequisites

- OpenWrt 25.12 on x86_64, the only target this fork builds
- sing-box, from the OpenWrt or ImmortalWrt package feed

## Feature

- Subscription management, remote or local
- Core Update (stable / preview / rollback)
- Scheduled Restart
- App, core and debug logs

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
/etc/init.d/gg update_core stable
# update to the latest preview release
/etc/init.d/gg update_core preview
# roll back to the previous version
/etc/init.d/gg rollback_core
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
opkg install gg
opkg install luci-app-gg
opkg install luci-i18n-gg-zh-cn
# for apk
apk add gg
apk add luci-app-gg
apk add luci-i18n-gg-zh-cn
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
# the file names carry the version, take them from the release page
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/gg-2026.10.14-r14.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-app-gg-1.2.2-r16.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-i18n-gg-<language>-<version>.apk

# install
apk add --allow-untrusted ./gg-2026.10.14-r14.apk \
                       ./luci-app-gg-1.2.2-r16.apk
```

Dependencies such as `sing-box` are still fetched from the official
OpenWrt repositories.

## Uninstall & Reset

```shell
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
```

## How To Use

See [Wiki](https://github.com/nikkinikki-org/OpenWrt-momo/wiki)

## How does it work
 
1. Pick a profile file or a subscription.
2. Fetch the subscription if it is remote or its file is missing.
3. Validate the profile and run the sing-box core with it.
4. Set up the scheduled restart and log clean up if enabled.

Note that the steps above may change base on config.

## Versioning

`PKG_VERSION` tracks the upstream version, `PKG_RELEASE` is this fork's own revision
number and is incremented on every release.

```
luci-app-gg  1.2.2-r16   (PKG_VERSION:=1.2.2, PKG_RELEASE:=16)
gg           2026.10.14-r14
```

`-rN` sorts above the upstream `-r1`, so a package manager picks this build up instead
of the upstream one. Keeping the upstream version visible is deliberate: it is
what tells you at a glance which upstream release the changes are based on.

**Every change to a file that ships inside a package must bump `PKG_RELEASE`.**
Without it the package keeps the version a user already has, the package manager
reports it as up to date and skips it, and the new files never reach the device.
This applies to `gg` (`gg.conf`, `files/`) and to `luci-app-gg` (`htdocs/`,
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
#      gg/Makefile          PKG_VERSION:=2026.10.14
#      luci-app-gg/Makefile PKG_VERSION:=1.2.2

# 3. reset PKG_RELEASE to 2, the first revision on top of that upstream version
```

Step 2 is the one to watch. `1.2.1-r2` outranks `1.2.1-r1`, but upstream's
`1.2.2-r1` outranks `1.2.1-r2` no matter how large `PKG_RELEASE` grows, and
`gg` uses a date based version that moves on every upstream release.

## Compilation

```shell
# add feed
echo "src-git gg https://github.com/580132/OpenWrt-momo.git;main" >> "feeds.conf.default"
# update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# make package
make package/luci-app-gg/compile
```

The package files will be found under `bin/packages/your_architecture/gg`.

## Dependencies

- ca-bundle
- curl
- sing-box

## Contributors

[![Contributors](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-momo)](https://github.com/nikkinikki-org/OpenWrt-momo/graphs/contributors)
