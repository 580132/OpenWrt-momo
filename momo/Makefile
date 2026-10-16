include $(TOPDIR)/rules.mk

PKG_NAME:=gg
PKG_VERSION:=2026.10.14
PKG_RELEASE:=5

PKG_LICENSE:=GPL-3.0+
PKG_MAINTAINER:=Joseph Mory <morytyann@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/gg
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Transparent Proxy with sing-box on OpenWrt (Core Only).
  URL:=https://github.com/nikkinikki-org
  DEPENDS:=+ca-bundle +curl firewall4 +ip-full +kmod-inet-diag +kmod-nft-socket +kmod-nft-tproxy +kmod-tun +kmod-dummy +sing-box
endef

define Package/gg/conffiles
/etc/config/gg
endef

define Package/gg/install
	$(INSTALL_DIR) $(1)/etc/gg
	$(INSTALL_DIR) $(1)/etc/gg/ucode
	$(INSTALL_DIR) $(1)/etc/gg/scripts
	$(INSTALL_DIR) $(1)/etc/gg/firewall
	$(INSTALL_DIR) $(1)/etc/gg/profiles
	$(INSTALL_DIR) $(1)/etc/gg/subscriptions
	$(INSTALL_DIR) $(1)/etc/gg/run
	$(INSTALL_DIR) $(1)/etc/gg/core

	$(INSTALL_BIN) $(CURDIR)/files/ucode/include.uc $(1)/etc/gg/ucode/include.uc
	$(INSTALL_BIN) $(CURDIR)/files/ucode/mixin.uc $(1)/etc/gg/ucode/mixin.uc
	$(INSTALL_BIN) $(CURDIR)/files/ucode/hijack.ut $(1)/etc/gg/ucode/hijack.ut

	$(INSTALL_BIN) $(CURDIR)/files/scripts/include.sh $(1)/etc/gg/scripts/include.sh
	$(INSTALL_BIN) $(CURDIR)/files/scripts/firewall_include.sh $(1)/etc/gg/scripts/firewall_include.sh
	$(INSTALL_BIN) $(CURDIR)/files/scripts/debug.sh $(1)/etc/gg/scripts/debug.sh
	$(INSTALL_BIN) $(CURDIR)/files/scripts/update_core.sh $(1)/etc/gg/scripts/update_core.sh

	$(INSTALL_BIN) $(CURDIR)/files/firewall/geoip_cn.nft $(1)/etc/gg/firewall/geoip_cn.nft
	$(INSTALL_BIN) $(CURDIR)/files/firewall/geoip6_cn.nft $(1)/etc/gg/firewall/geoip6_cn.nft

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/momo.conf $(1)/etc/config/gg

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/momo.init $(1)/etc/init.d/gg

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(CURDIR)/files/uci-defaults/firewall.sh $(1)/etc/uci-defaults/99_firewall_gg
	$(INSTALL_BIN) $(CURDIR)/files/uci-defaults/init.sh $(1)/etc/uci-defaults/99_init_gg
	$(INSTALL_BIN) $(CURDIR)/files/uci-defaults/migrate.sh $(1)/etc/uci-defaults/99_migrate_gg

	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) $(CURDIR)/files/momo.upgrade $(1)/lib/upgrade/keep.d/gg
endef

define Package/gg/postrm
#!/bin/sh
if [ -z $${IPKG_INSTROOT} ]; then
	uci -q batch <<-EOF > /dev/null
		del firewall.gg
		commit firewall
	EOF
fi
endef

define Build/Compile

endef

$(eval $(call BuildPackage,gg))