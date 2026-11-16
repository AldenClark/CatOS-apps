#!/usr/bin/env bash
# Structural checks that do not require an OpenWrt target or network credentials.
set -euo pipefail
cd "$(dirname "$0")/.."

core=net/catos-notify/files
ui=luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify.js
ui_dir=luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify

for file in "$core"/catos-notify "$core"/catos-notify-{dispatch,providers,monitor,rpcd} "$core"/catos-notify.{init,hotplug,cgi}; do
	sh -n "$file"
done
node --check "$ui"
for file in "$ui_dir"/*.js; do
	node --check "$file"
done

node - "$core/catos_notify.config" "$ui_dir/rules.js" "$ui_dir/channels.js" "$core/catos-notify-providers" <<'NODE'
const fs = require('fs');
const assert = require('assert');
const [config, uiRules, uiChannels, provider] = process.argv.slice(2).map(p => fs.readFileSync(p, 'utf8'));
// UCI section names are unique across *all* section types. A template and a
// rule both called "summary" cause rpcd uci/get to fail with ubus code 9.
const sectionNames = new Set();
for (const match of config.matchAll(/^\s*config\s+\S+\s+(['"])([^'"]+)\1\s*$/gm)) {
  const name = match[2];
  assert(!sectionNames.has(name), 'Duplicate UCI section name: ' + name);
  sectionNames.add(name);
}
const events = [
  'wan.down', 'wan.up', 'wan.ipv4.changed', 'wan.ipv6.changed',
  'wan.prefix.changed', 'public.ipv4.changed', 'public.ipv6.changed',
  'wan.primary.changed', 'device.unknown.online', 'device.known.online',
  'device.known.offline', 'auth.ssh.failed', 'auth.luci.failed',
  'system.boot', 'system.reboot', 'health.cpu_temp.high',
  'health.load.high', 'health.memory.high', 'health.storage.low',
  'system.summary',
];
const providers = ['bark','pushgo','ntfy','feishu','dingtalk','wecom','telegram','webhook'];
for (const event of events) {
  assert(config.includes("option event '" + event + "'"), 'Missing default rule: ' + event);
  assert(uiRules.includes("'"+ event + "'"), 'Missing LuCI event: ' + event);
}
for (const p of providers) {
  assert(new RegExp('\\b' + p + '\\)').test(provider), 'Missing provider handler: ' + p);
  assert(uiChannels.includes("'"+ p + "'"), 'Missing provider selector: ' + p);
}
assert(config.includes("option receiver_enabled '0'"), 'Receiver must default off');
assert(config.includes("option receiver_scope 'lan'"), 'Receiver must default to LAN');
assert(config.includes("option receiver_auth '1'"), 'Receiver auth must default on');
console.log('CatOS Notify: 20 events, 8 providers, secure defaults and shell/JS syntax verified.');
NODE

node - <<'NODE'
const fs = require('fs');
const assert = require('assert');
const app = 'luci/luci-app-catos-notify';
const base = `${app}/htdocs/luci-static/resources/view/`;
const menu = JSON.parse(fs.readFileSync(`${app}/root/usr/share/luci/menu.d/luci-app-catos-notify.json`, 'utf8'));
const parent = menu['admin/services/catos-notify'];
assert.equal(parent.action.type, 'firstchild');
const children = Object.entries(menu).filter(([key]) => key.startsWith('admin/services/catos-notify/'));
assert.equal(children.length, 6, 'Expected six semantic Notify pages');
for (const [key, entry] of children) {
  assert.equal(entry.action.type, 'view', `Invalid view action: ${key}`);
  assert(fs.existsSync(`${base}${entry.action.path}.js`), `Missing view: ${entry.action.path}`);
}
const views = children.map(([, entry]) => fs.readFileSync(`${base}${entry.action.path}.js`, 'utf8')).join('\n');
const settings = [
  'enabled', 'router_name', 'queue_limit', 'request_timeout', 'retry_limit',
  'wan_interfaces', 'device_interface', 'discover_devices', 'monitor_interval',
  'known_probe_interval', 'public_ip_enabled', 'public_ip_interval',
  'summary_interval', 'auth_failures', 'auth_window', 'cpu_temperature',
  'load_threshold', 'memory_available_mb', 'storage_available_mb', 'storage_mount',
  'receiver_enabled', 'receiver_scope', 'receiver_auth', 'receiver_token',
  'receiver_lan_interfaces', 'receiver_rate_limit',
];
for (const setting of settings) {
  assert(views.includes(`'${setting}'`), `Missing setting in LuCI: ${setting}`);
}
console.log('CatOS Notify: six linked LuCI views and all 26 service settings verified.');
NODE
