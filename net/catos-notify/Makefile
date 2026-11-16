include $(TOPDIR)/rules.mk

PKG_NAME:=catos-notify
PKG_VERSION:=0.2.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/catos-notify
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CatOS notification service
  URL:=https://github.com/AldenClark/CatOS-apps
  PKGARCH:=all
  DEPENDS:=+curl +ca-bundle +jsonfilter +libubox +ubus +openssl-util
endef

define Package/catos-notify/description
  Lightweight event notifications with multiple providers,
  UCI configuration, local CLI/ubus integration, and opt-in HTTP reception.
endef

define Package/catos-notify/conffiles
/etc/config/catos_notify
endef

define Build/Compile
endef

define Package/catos-notify/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/usr/bin $(1)/usr/libexec/catos-notify
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/hotplug.d/iface
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd $(1)/www/cgi-bin
	$(INSTALL_CONF) ./files/catos_notify.config $(1)/etc/config/catos_notify
	chmod 0600 $(1)/etc/config/catos_notify
	$(INSTALL_BIN) ./files/catos-notify $(1)/usr/bin/catos-notify
	$(INSTALL_BIN) ./files/catos-notify-dispatch $(1)/usr/libexec/catos-notify/dispatch
	$(INSTALL_BIN) ./files/catos-notify-monitor $(1)/usr/libexec/catos-notify/monitor
	$(INSTALL_BIN) ./files/catos-notify-providers $(1)/usr/libexec/catos-notify/providers
	$(INSTALL_BIN) ./files/catos-notify-rpcd $(1)/usr/libexec/rpcd/catos.notify
	$(INSTALL_BIN) ./files/catos-notify.init $(1)/etc/init.d/catos-notify
	$(INSTALL_BIN) ./files/catos-notify.hotplug $(1)/etc/hotplug.d/iface/95-catos-notify
	$(INSTALL_BIN) ./files/catos-notify.cgi $(1)/www/cgi-bin/catos-notify
endef

define Package/catos-notify/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
chmod 0600 /etc/config/catos_notify 2>/dev/null || true
/etc/init.d/catos-notify enable 2>/dev/null || true
/etc/init.d/catos-notify restart 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
exit 0
endef

define Package/catos-notify/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
/etc/init.d/catos-notify stop 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,catos-notify))
