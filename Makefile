# OpenWrt package Makefile for the OpenWrt SDK / buildroot.
#
# Build (SDK of any target; the packages are architecture independent):
#   ln -s /path/to/openwrt_vpn_hostnames <sdk>/package/vpn-hostnames
#   make defconfig
#   make package/vpn-hostnames/compile
# The packages land in <sdk>/bin/packages/<arch>/base/ (wg-hosts-*.apk, openvpn-hosts-*.apk).
# Install unsigned packages with: apk add --allow-untrusted ./wg-hosts-*.apk
#
# Files are installed to the same paths as in this repository (/usr/local/bin), so the
# manual install described in README.md and a package install are interchangeable.

include $(TOPDIR)/rules.mk

PKG_NAME:=vpn-hostnames
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Thomas Wagner <wagner-thomas@gmx.at>
PKG_LICENSE:=LGPL-2.1-only
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/vpn-hostnames/Default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  PKGARCH:=all
  URL:=https://github.com/Aikhjarto/openwrt_vpn_hostnames
endef

define Package/wg-hosts
  $(call Package/vpn-hostnames/Default)
  TITLE:=DNS names in dnsmasq for connected WireGuard peers
  DEPENDS:=+wireguard-tools
endef

define Package/wg-hosts/description
  Puts "IP hostname" of WireGuard peers with a recent handshake into
  /tmp/hosts/wireguard-<iface>, so dnsmasq resolves a client's usual hostname to its tunnel
  address while it is connected. Names come from "option hostname" in the peer sections
  of /etc/config/network. Clients need PersistentKeepalive.
endef

define Package/openvpn-hosts
  $(call Package/vpn-hostnames/Default)
  TITLE:=DNS names in dnsmasq for connected OpenVPN clients
endef

define Package/openvpn-hosts/description
  client-connect / client-disconnect scripts that put "pool-IP common-name" of connected
  OpenVPN clients into /tmp/hosts/openvpn for dnsmasq. Set client_connect and
  client_disconnect in /etc/config/openvpn to the installed scripts (see README.md).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/wg-hosts/install
	$(INSTALL_DIR) $(1)/usr/local/bin $(1)/etc/init.d
	$(INSTALL_BIN) ./usr/local/bin/wg-hosts.sh $(1)/usr/local/bin/
	$(INSTALL_BIN) ./etc/init.d/wg-hosts $(1)/etc/init.d/
endef

define Package/openvpn-hosts/install
	$(INSTALL_DIR) $(1)/usr/local/bin
	$(INSTALL_BIN) ./usr/local/bin/openvpn_client_script.sh $(1)/usr/local/bin/
	$(INSTALL_BIN) ./usr/local/bin/openvpn_client_connect.sh $(1)/usr/local/bin/
	$(INSTALL_BIN) ./usr/local/bin/openvpn_client_disconnect.sh $(1)/usr/local/bin/
endef

$(eval $(call BuildPackage,wg-hosts))
$(eval $(call BuildPackage,openvpn-hosts))
