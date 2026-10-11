![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-momo/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

中文 | [English](README.md)

# Momo

在 OpenWrt 上使用 sing-box 进行透明代理。

## 环境要求

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## 功能

- 透明代理 (Redirect/TPROXY/TUN, IPv4 和/或 IPv6)
- 访问控制
- 配置文件编辑器
- 定时重启
- 核心更新 (稳定版 / 预览版 / 回滚)

## 核心更新

在 `插件配置` -> `核心更新` 中可以直接更新 sing-box 核心。

- **检查更新** - 从 sing-box 发布页获取最新稳定版与预览版版本号。
- **更新到最新稳定版** / **更新到最新预览版** - 下载 sing-box 为当前路由器目标架构提供的官方
  OpenWrt 安装包（`.ipk` / `.apk`），通过 `opkg` / `apk` 安装，然后重启服务。预览版为预发布版本，
  可能存在不稳定性。
- **回滚核心** - 重新安装上一次更新之前使用的版本。

更新过程在后台执行，进度会显示在弹窗中。所有步骤都会写入插件日志，`opkg` / `apk` 的输出也会
一并记录，便于排查问题。

注意：

- 核心以常规 `sing-box` 软件包的形式安装，因此 `opkg upgrade sing-box` / `apk` 仍可将其还原为
  软件源中的版本。
- 固件分区至少需要 128 MiB 可用空间，`/tmp` 还需留出下载所需的空间，脚本会在下载前检查。
- 也可以在 shell 中执行同样的操作：

```
# 更新到最新稳定版
/etc/init.d/momo update_core stable
# 更新到最新预览版
/etc/init.d/momo update_core preview
# 回滚到上一个版本
/etc/init.d/momo rollback_core
```

## 安装和更新

> **支持的平台：** 本 fork 目前只构建 `openwrt-25.12` 的 `x86_64`，其他架构和版本不会发布到软件源。

### A. 从软件源安装（推荐）

1. 添加源

```shell
# 只需运行一次
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/feed.sh | ash
```

2. 安装

```shell
# 你可以从 shell 执行命令安装或者从 LuCI 的`软件包`菜单安装
# for opkg
opkg install momo
opkg install luci-app-momo
opkg install luci-i18n-momo-zh-cn
# for apk
apk add momo
apk add luci-app-momo
apk add luci-i18n-momo-zh-cn
```

### B. 从发行版安装

从最新的 GitHub 发行版直接下载安装包，**不需要添加软件源，也不需要信任任何签名密钥**，
开箱即用。

```shell
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/install-release.sh | ash
```

### C. 直接安装安装包

不想添加软件源时用这个方式。随发行版发布的安装包**未签名**，因此需要 `--allow-untrusted`
跳过签名校验。

```shell
# 下载最新发行版的安装包
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/momo-2026.06.03-r2.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-app-momo-1.2.1-r2.apk
wget https://github.com/580132/OpenWrt-momo/releases/latest/download/luci-i18n-momo-zh-cn-26.284.47581~d6a2dbc.apk

# 安装
apk add --allow-untrusted ./momo-2026.06.03-r2.apk \
                       ./luci-app-momo-1.2.1-r2.apk \
                       ./luci-i18n-momo-zh-cn-26.284.47581~d6a2dbc.apk
```

`firewall4`、`sing-box` 等依赖仍会从 OpenWrt 官方软件源获取。

## 卸载并重置

```shell
wget -O - https://github.com/580132/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
```

## 如何使用

查看 [Wiki](https://github.com/nikkinikki-org/OpenWrt-momo/wiki)

## 如何工作

1. 启动 sing-box。
2. 设置定时重启。
3. 从配置文件读取必要的参数。
4. 配置 IP 规则/路由。
5. 生成防火墙配置并应用。

注意上述步骤可能因配置而变动。

## 版本号

`PKG_VERSION` 跟随上游版本，`PKG_RELEASE` 是本 fork 自己的修订号，每次发版递增。

```
luci-app-momo  1.2.1-r2        (PKG_VERSION:=1.2.1, PKG_RELEASE:=2)
momo           2026.06.03-r2
```

`-rN` 的排序高于上游的 `-r1`，因此包管理器会优先安装本仓库的构建产物，而不是上游的。

保留上游版本号是刻意的：一眼就能看出当前改动是基于哪个上游版本。

### 同步上游

上游发布新版本后必须跟进，否则上游的包会变成更新的版本，把本仓库的构建产物替换掉：

```shell
# 1. 合并或变基到上游对应的 tag
git remote add upstream https://github.com/nikkinikki-org/OpenWrt-momo.git
git fetch upstream
git merge upstream/v1.2.1        # 或要同步的那个 tag

# 2. 把两个 Makefile 的 PKG_VERSION 改成上游版本
#      momo/Makefile          PKG_VERSION:=2026.06.03
#      luci-app-momo/Makefile PKG_VERSION:=1.2.1

# 3. 把 PKG_RELEASE 重置为 2，表示基于该上游版本的第一次修改
```

第 2 步最容易被漏掉。`1.2.1-r2` 高于 `1.2.1-r1`，但上游的 `1.2.2-r1` 无论你把
`PKG_RELEASE` 调到多大都高于 `1.2.1-r2`；而且 `momo` 用的是日期版本号，上游每次
发布都会变。

## 编译

```shell
# 添加源
echo "src-git momo https://github.com/580132/OpenWrt-momo.git;main" >> "feeds.conf.default"
# 更新并安装源
./scripts/feeds update -a
./scripts/feeds install -a
# 编译
make package/luci-app-momo/compile
```

编译结果可以在`bin/packages/your_architecture/momo`内找到。

## 依赖

- ca-bundle
- curl
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- sing-box >= 1.12

## 贡献者

[![贡献者](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-momo)](https://github.com/nikkinikki-org/OpenWrt-momo/graphs/contributors)
