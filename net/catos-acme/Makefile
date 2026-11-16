include $(TOPDIR)/rules.mk

PKG_NAME:=catos-acme
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/catos-acme
  SECTION:=net
  CATEGORY:=Network
  TITLE:=CatOS ACME certificate management
  URL:=https://github.com/AldenClark/CatOS-apps
  PKGARCH:=all
endef

define Package/catos-acme/description
  Initial package framework for CatOS ACME certificate management.
  Certificate issuance and deployment are not implemented in this release.
endef

define Package/catos-acme/conffiles
/etc/config/catos_acme
endef

define Build/Compile
endef

define Package/catos-acme/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/catos_acme.config $(1)/etc/config/catos_acme
endef

$(eval $(call BuildPackage,catos-acme))
