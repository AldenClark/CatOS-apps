include $(TOPDIR)/rules.mk

PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

LUCI_TITLE:=CatOS Notify LuCI interface
LUCI_DEPENDS:=+luci-base +catos-notify
LUCI_PKGARCH:=all
LUCI_URL:=https://github.com/AldenClark/CatOS-apps

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
