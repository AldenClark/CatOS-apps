#!/usr/bin/env bash
# Structural checks that do not require an OpenWrt target or network credentials.
set -euo pipefail
cd "$(dirname "$0")/.."

core=net/catos-notify/files
ui=luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify.js

for file in "$core"/catos-notify "$core"/catos-notify-{dispatch,providers,monitor,rpcd} "$core"/catos-notify.{init,hotplug,cgi}; do
	sh -n "$file"
done
node --check "$ui"

node - "$core/catos_notify.config" "$ui" "$core/catos-notify-providers" <<'NODE'
const fs = require('fs');
const assert = require('assert');
const [config, ui, provider] = process.argv.slice(2).map(p => fs.readFileSync(p, 'utf8'));
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
  assert(ui.includes("'"+ event + "'"), 'Missing LuCI event: ' + event);
}
for (const p of providers) {
  assert(new RegExp('\\b' + p + '\\)').test(provider), 'Missing provider handler: ' + p);
  assert(ui.includes("'"+ p + "'"), 'Missing provider selector: ' + p);
}
assert(config.includes("option receiver_enabled '0'"), 'Receiver must default off');
assert(config.includes("option receiver_scope 'lan'"), 'Receiver must default to LAN');
assert(config.includes("option receiver_auth '1'"), 'Receiver auth must default on');
console.log('CatOS Notify: 20 events, 8 providers, secure defaults and shell/JS syntax verified.');
NODE
