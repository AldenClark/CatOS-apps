include $(TOPDIR)/rules.mk

PKG_NAME:=catos-ddns
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/catos-ddns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CatOS dynamic DNS service
  URL:=https://github.com/AldenClark/CatOS-apps
  PKGARCH:=all
endef

define Package/catos-ddns/description
  Initial package framework for the CatOS dynamic DNS service.
  DNS record updates are not implemented in this release.
endef

define Package/catos-ddns/conffiles
/etc/config/catos_ddns
endef

define Build/Compile
endef

define Package/catos-ddns/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/catos_ddns.config $(1)/etc/config/catos_ddns
endef

$(eval $(call BuildPackage,catos-ddns))
