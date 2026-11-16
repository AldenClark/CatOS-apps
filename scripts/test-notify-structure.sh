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

# Exercise the actual shell helper used by test sends, event rules and device
# probes. LuCI omits a Flag when it equals its default unless rmempty=false.
check_section_flag() {
	local implementation
	implementation="$(sed -n '/^section_flag() {/,/^}/p' "$1")"
	[ -n "$implementation" ] || { echo "Missing section_flag in $1" >&2; return 1; }
	(
		eval "$implementation"
		field() { printf '%s' "$MOCK_FLAG"; }
		MOCK_FLAG=''
		section_flag sample enabled 1
		! section_flag sample enabled 0
		MOCK_FLAG=1
		section_flag sample enabled 1
		MOCK_FLAG=0
		! section_flag sample enabled 1
		MOCK_FLAG=invalid
		! section_flag sample enabled 1
	)
}
check_section_flag "$core/catos-notify-dispatch"
check_section_flag "$core/catos-notify-monitor"

# Manual test must not depend on a channel's enabled flag (nor the global
# service flag). Both remain enforced on normal event/message routing.
test_handler="$(sed -n '/^do_test() {/,/^}/p' "$core/catos-notify-dispatch")"
[ -n "$test_handler" ] || { echo 'Missing manual test handler' >&2; exit 1; }
if printf '%s' "$test_handler" | grep -Eq 'section_flag|setting enabled'; then
	echo 'Manual test must work on disabled channels' >&2
	exit 1
fi

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
const uiDevices = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/devices.js', 'utf8');
for (const [script, name] of [[uiChannels, 'enabled'], [uiRules, 'enabled'], [uiDevices, 'monitor']]) {
  assert(new RegExp("option\\(form\\.Flag, '" + name + "'[\\s\\S]{0,140}?o\\.default = '1';\\s*o\\.rmempty = false;").test(script),
    `Default-on ${name} checkbox must persist its explicit value`);
}
assert(uiChannels.includes("o.modalonly = false;"), 'Channel test must be outside the edit dialog');
assert(uiChannels.includes('uci.changes().then('), 'Channel test must reject un-applied UCI changes');
console.log('CatOS Notify: 20 events, 8 providers, secure defaults and shell/JS syntax verified.');
NODE

node - <<'NODE'
const assert = require('assert');
const fs = require('fs');
const source = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/rules.js', 'utf8');
// LuCI supplies String.format(), including %h escaping.
String.prototype.format = function(value) {
  return this.replace('%h', String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'));
};
function renderRules(translate) {
  const options = [];
  let storedEvent = '';
  const section = {option(_type, key, title) {
    const option = {key, title, values: [], value(id, label) { this.values.push([id, label]); }, cfgvalue() { return storedEvent; }};
    options.push(option);
    return option;
  }};
  const form = {
    Map: function() { this.section = () => section; this.render = () => options; },
    GridSection: function(){}, Flag: function(){}, Value: function(){}, ListValue: function(){}
  };
  const view = Function('view', 'form', '_', source)({extend: o => o}, form, translate);
  const result = view.render();
  return {event: result.find(o => o.key === 'event'), setStoredEvent: id => { storedEvent = id; }};
}
const english = renderRules(s => s);
assert.equal(english.event.title, 'Event', 'Grid column should describe an event, not expose its storage ID');
for (const [id, label] of english.event.values) {
  english.setStoredEvent(id);
  assert.equal(english.event.textvalue('sample'), label, `Missing human-readable event label for ${id}`);
}
english.setStoredEvent('ddns.updated');
assert.equal(english.event.textvalue('sample'), 'ddns.updated', 'Custom event IDs must remain visible');
english.setStoredEvent('<unsafe.event>');
assert.equal(english.event.textvalue('sample'), '&lt;unsafe.event&gt;', 'Custom event IDs must be HTML-escaped');
const chinese = renderRules(s => s === 'WAN · Disconnected' ? 'WAN · 连接断开' : s);
chinese.setStoredEvent('wan.down');
assert.equal(chinese.event.textvalue('sample'), 'WAN · 连接断开', 'Grid label must follow LuCI language');
console.log('CatOS Notify: all event IDs display translated labels while retaining raw UCI IDs.');
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

node - <<'NODE'
const assert = require('assert');
const fs = require('fs');
const root = 'luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/';
const source = fs.readFileSync(root + 'notify.js', 'utf8');
const css = fs.readFileSync(root + 'notify/overview.css', 'utf8');
assert.equal((css.match(/\{/g) || []).length, (css.match(/\}/g) || []).length, 'Overview CSS braces must balance');
assert(/\.catos-notify-compose-row\s*\{[^}]*grid-template-columns:\s*160px minmax\(0, 1fr\)/s.test(css), 'Desktop composer must use stable grid columns');
assert(/@media\s*\(max-width:\s*640px\)[\s\S]*grid-template-columns:\s*minmax\(0, 1fr\)/.test(css), 'Mobile composer must stack labels and inputs');

const notifications = [];
const sent = [];
function E(tag, attrs = {}, contents) {
  return {tag, attrs, children: Array.isArray(contents) ? contents : contents == null ? [] : [contents], value: ''};
}
function find(rootNode, predicate) {
  if (typeof rootNode !== 'object' || rootNode === null) return null;
  if (predicate(rootNode)) return rootNode;
  for (const child of rootNode.children || []) {
    const match = find(child, predicate);
    if (match) return match;
  }
  return null;
}
const rpc = { declare: ({method}) => (...args) => {
  if (method === 'send') { sent.push(args); return Promise.resolve({ok: true}); }
  return Promise.resolve({enabled: true, queued: 0, history: []});
}};
const app = Function('E', '_', 'view', 'rpc', 'ui', 'L', source)(
  E, s => s, {extend: view => view}, rpc,
  {addNotification: (_title, content) => notifications.push(content)},
  {resource: p => p});
const tree = app.render({enabled: true, queued: 0, history: []});
assert(find(tree, n => n.tag === 'link' && n.attrs.href === 'view/catos/notify/overview.css'), 'Overview stylesheet must be loaded');
const compose = find(tree, n => n.attrs?.class === 'catos-notify-compose');
assert(compose && compose.children.length === 4, 'Composer must have three fields and one action row');
const fields = ['title', 'body', 'group'];
for (let i = 0; i < fields.length; i++) {
  const row = compose.children[i];
  assert.equal(row.attrs.class, 'catos-notify-compose-row');
  assert.equal(row.children[0].attrs.for, 'catos-notify-' + fields[i]);
  assert.equal(row.children[1].attrs.class, 'catos-notify-compose-control');
}
const button = find(compose, n => n.tag === 'button');
assert(button && typeof button.attrs.click === 'function', 'Send button must remain interactive');
const title = find(compose, n => n.attrs?.id === 'catos-notify-title');
const body = find(compose, n => n.attrs?.id === 'catos-notify-body');
button.attrs.click({currentTarget: button});
assert.equal(sent.length, 0, 'An empty message must be rejected');
title.value = 'Test';
body.value = 'Example';
(async () => {
  await button.attrs.click({currentTarget: button});
  assert.deepEqual(sent, [['Test', 'Example', 'default']]);
  assert.equal(button.disabled, false, 'Send button must be re-enabled after completion');
  assert(notifications.length >= 2, 'Validation and success feedback must be shown');
  console.log('CatOS Notify: overview composer structure, responsive CSS and button flow verified.');
})().catch(error => { console.error(error); process.exitCode = 1; });
NODE
