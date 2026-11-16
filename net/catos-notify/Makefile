include $(TOPDIR)/rules.mk

PKG_NAME:=catos-notify
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/catos-notify
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CatOS notification service
  URL:=https://github.com/AldenClark/CatOS-apps
  PKGARCH:=all
endef

define Package/catos-notify/description
  Initial package framework for the CatOS notification service.
  Notification delivery is not implemented in this release.
endef

define Package/catos-notify/conffiles
/etc/config/catos_notify
endef

define Build/Compile
endef

define Package/catos-notify/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/catos_notify.config $(1)/etc/config/catos_notify
endef

$(eval $(call BuildPackage,catos-notify))
