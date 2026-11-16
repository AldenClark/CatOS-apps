#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for app in notify ddns acme; do
  core="net/catos-${app}"
  luci="luci/luci-app-catos-${app}"
  config="${core}/files/catos_${app}.config"
  view="${luci}/htdocs/luci-static/resources/view/catos/${app}.js"
  menu="${luci}/root/usr/share/luci/menu.d/luci-app-catos-${app}.json"
  acl="${luci}/root/usr/share/rpcd/acl.d/luci-app-catos-${app}.json"

  for file in "${core}/Makefile" "${config}" "${luci}/Makefile" "${view}" "${menu}" "${acl}"; do
    if [[ ! -f "${file}" ]]; then
      printf 'Missing package file: %s\n' "${file}" >&2
      exit 1
    fi
  done

  grep -q "PKG_NAME:=catos-${app}" "${core}/Makefile"
  grep -q "LUCI_DEPENDS:=+luci-base +catos-${app}" "${luci}/Makefile"
  grep -q 'call BuildPackage' "${luci}/Makefile"
  grep -q "config settings 'main'" "${config}"

  node --check "${view}"
  node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(process.argv[1], "utf8"));' "${menu}"
  node -e 'const fs=require("fs"); JSON.parse(fs.readFileSync(process.argv[1], "utf8"));' "${acl}"
done

for view in luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/*.js; do
  node --check "$view"
done
node scripts/check-notify-i18n.js
grep -q 'PKG_NAME:=luci-i18n-catos-notify-zh-cn' luci/luci-i18n-catos-notify-zh-cn/Makefile
grep -q 'PKG_BUILD_DEPENDS:=luci-base/host' luci/luci-i18n-catos-notify-zh-cn/Makefile
grep -q 'po2lmo ./po/zh_Hans/catos-notify.po' luci/luci-i18n-catos-notify-zh-cn/Makefile
test ! -f luci/luci-app-catos-notify/po/zh_Hans/catos-notify.po

printf 'Validated 3 core packages and 3 LuCI packages.\n'
