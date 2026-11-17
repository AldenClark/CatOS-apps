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

# Exercise the actual routing functions with named channel/group fixtures.
# The same channel selected directly and through groups must be queued once.
(
	eval "$(sed -n '/^queue_channel() {/,/^}/p' "$core/catos-notify-dispatch")"
	eval "$(sed -n '/^route_channels() {/,/^}/p' "$core/catos-notify-dispatch")"
	eval "$(sed -n '/^valid_section_id() {/,/^}/p' "$core/catos-notify-dispatch")"
	CONFIG=catos_notify
	uci() {
		[ "$1" = -q ] && shift
		[ "$1" = get ] || return 1
		case "$2" in
			catos_notify.team|catos_notify.backup) printf group ;;
			catos_notify.phone|catos_notify.bark|catos_notify.disabled) printf channel ;;
			*) return 1 ;;
		esac
	}
	field() {
		case "$1.$2" in
			team.channels) printf 'phone bark' ;;
			backup.channels) printf 'phone disabled' ;;
		esac
	}
	section_flag() { [ "$1" != disabled ]; }
	queue_target() { QUEUED="$QUEUED $1"; }
	history() { return 1; }
	TITLE=example BODY=content SEVERITY=normal EVENT=wan.down
	ROUTES='group:team channel:phone group:backup channel:disabled'
	QUEUED=
	route_channels
	[ "$DELIVERY_COUNT" = 2 ] && [ "$QUEUED" = ' phone bark' ] || {
		echo 'Grouped routing must deduplicate channels and exclude disabled members' >&2
		exit 1
	}
	ROUTES='group:removed channel:removed group:team'
	QUEUED=
	route_channels
	[ "$DELIVERY_COUNT" = 2 ] && [ "$QUEUED" = ' phone bark' ] || {
		echo 'Removed references must not redirect to another channel' >&2
		exit 1
	}
	ROUTES=
	QUEUED=
	route_channels
	[ "$DELIVERY_COUNT" = 0 ] && [ -z "$QUEUED" ] || {
		echo 'Empty targets must never fall back to a default group' >&2
		exit 1
	}
)

(
	eval "$(sed -n '/^valid_section_id() {/,/^}/p' "$core/catos-notify-dispatch")"
	eval "$(sed -n '/^read_targets() {/,/^}/p' "$core/catos-notify-dispatch")"
	MOCK_KIND=array
	MOCK_ROUTES='group:admins channel:phone'
	json_get_type() { printf -v "$1" '%s' "$MOCK_KIND"; }
	json_get_values() { printf -v "$1" '%s' "$MOCK_ROUTES"; }
	read_targets && [ "$ROUTES" = "$MOCK_ROUTES" ] || {
		echo 'Explicit target arrays must parse' >&2
		exit 1
	}
	MOCK_ROUTES='group:../../etc/passwd'
	! read_targets || { echo 'Invalid section IDs must be rejected' >&2; exit 1; }
	MOCK_ROUTES=
	! read_targets || { echo 'Empty target arrays must be rejected' >&2; exit 1; }
	MOCK_KIND=string
	MOCK_ROUTES='channel:phone'
	! read_targets || { echo 'Targets must be passed as an array' >&2; exit 1; }
)

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
assert(!/^\s*config template\b/m.test(config), 'Templates must be owned by rules');
assert(!/^\s*option (group|template)\b/m.test(config), 'Default rules must not use legacy routing fields');
for (const block of config.split(/^config rule '[^']+'\s*$/gm).slice(1)) {
  assert(/option title '/.test(block) && /option body '/.test(block), 'Each rule needs an independent template');
  assert(!/\blist targets\b/.test(block), 'No implicit delivery targets in default rules');
}
assert(!uiChannels.includes("s.option(form.Value, 'group'"), 'Channel must not own a delivery group');
assert(uiRules.includes("s.option(form.MultiValue, 'targets'"), 'Rules must support multiple delivery destinations');
assert(config.includes("option receiver_enabled '0'"), 'Receiver must default off');
assert(config.includes("option receiver_scope 'lan'"), 'Receiver must default to LAN');
assert(config.includes("option receiver_auth '1'"), 'Receiver auth must default on');
const uiDevices = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/devices.js', 'utf8');
for (const [script, name] of [[uiChannels, 'enabled'], [uiRules, 'enabled'], [uiDevices, 'monitor']]) {
  assert(new RegExp("option\\(form\\.Flag, '" + name + "'[\\s\\S]{0,140}?o\\.default = '1';\\s*o\\.rmempty = false;").test(script),
    `Default-on ${name} checkbox must persist its explicit value`);
}
assert(/s.option\(form.Button, '_test'[\s\S]*?o.modalonly = true;/.test(uiChannels), 'Channel test must be in the edit dialog');
assert(uiChannels.includes('uci.changes().then('), 'Channel test must reject un-applied UCI changes');
console.log('CatOS Notify: 20 events, 8 providers, secure defaults and shell/JS syntax verified.');
NODE

node - <<'NODE'
globalThis.L = {resource: p => p};
globalThis.E = () => ({});
const assert = require('assert');
const fs = require('fs');
const base = 'luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/';
const groupSource = fs.readFileSync(base + 'groups.js', 'utf8');
const channelSource = fs.readFileSync(base + 'channels.js', 'utf8');
async function inspectView(source, type) {
  let section, addedId;
  const options = [];
  const form = {
    Map: function() {
      this.data = {get: () => null};
      this.section = () => section = {
        map: this,
        handleAdd(_ev, id) { addedId = id; return id; },
        option(_cls, key, title) {
          const result = {key, title, values: [], value(value, label) {this.values.push([value, label]);}, depends() {}};
          options.push(result);
          return result;
        }
      };
      this.render = () => Promise.resolve(Object.assign(options, {classList: {add() {}}, prepend() {}, querySelectorAll() {return []}}));
    },
    GridSection: function(){}, Flag: function(){}, Value: function(){},
    ListValue: function(){}, MultiValue: function(){}, Button: function(){}
  };
  const uci = {sections: (_config, kind) => kind === 'channel' ? [{'.name':'phone',name:'My phone'}] : []};
  const rpc = {declare: () => () => Promise.resolve({ok:true})};
  const app = Function('view','form','uci','rpc','ui','_',source)(
    {extend: v=>v}, form, uci, rpc, {addNotification:()=>{}}, s=>s);
  await app.render();
  section.handleAdd({});
  assert(new RegExp(`^${type}_[a-z0-9_]+$`).test(addedId), `${type} must use a stable named UCI section`);
  return options;
}
(async () => {
const groups = await inspectView(groupSource, 'group');
assert.deepEqual(groups.find(o => o.key === 'channels').values, [['phone', 'My phone']]);
assert(!groups.some(o => o.key === 'group'), 'Group members must be configured on the group itself');
const channels = await inspectView(channelSource, 'channel');
assert(!channels.some(o => o.key === 'group'), 'Channel editor must have no group input');
console.log('CatOS Notify: stable channel/group section IDs and group-member selector verified.');
})().catch(error => { console.error(error); process.exitCode = 1; });
NODE

node - <<'NODE'
globalThis.L = {resource: p => p};
globalThis.E = () => ({});
const assert = require('assert');
const fs = require('fs');
const source = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/rules.js', 'utf8');
// LuCI supplies String.format(), including %h escaping.
String.prototype.format = function(value) {
  return this.replace('%h', String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'));
};
async function renderRules(translate) {
  const options = [];
  let storedEvent = '';
const section = {option(_type, key, title) {
    const option = {key, title, values: [], value(id, label) { this.values.push([id, label]); }, cfgvalue() { return key === 'event' ? storedEvent : key === 'targets' ? ['group:admins', 'channel:phone'] : ''; }};
    options.push(option);
    return option;
  }};
  const form = {
    Map: function() { this.section = () => section; this.render = () => Promise.resolve(Object.assign(options, {classList: {add() {}}, prepend() {}, querySelectorAll() {return []}})); },
    GridSection: function(){}, Flag: function(){}, Value: function(){}, ListValue: function(){},
    MultiValue: function(){}, TextValue: function(){}, DummyValue: function(){}
  };
  const uci = {
    sections: (_config, kind) => kind === 'channel' ? [{'.name':'phone',name:'Phone'}] : [{'.name':'admins',name:'Administrators'}],
    get: () => 'wan.down'
  };
  const view = Function('view', 'form', 'uci', '_', source)({extend: o => o}, form, uci, translate);
  const result = await view.render();
  return {event: result.find(o => o.key === 'event'), delivery: result.find(o => o.key === 'targets'),
    vars: result.find(o => o.key === '_variables'), setStoredEvent: id => { storedEvent = id; }};
}
(async () => {
const english = await renderRules(s => s);
assert.equal(english.event.title, 'Event', 'Grid column should describe an event, not expose its storage ID');
for (const [id, label] of english.event.values) {
  english.setStoredEvent(id);
  assert.equal(english.event.textvalue('sample'), label, `Missing human-readable event label for ${id}`);
}
english.setStoredEvent('ddns.updated');
assert.equal(english.event.textvalue('sample'), 'ddns.updated', 'Custom event IDs must remain visible');
english.setStoredEvent('<unsafe.event>');
assert.equal(english.event.textvalue('sample'), '&lt;unsafe.event&gt;', 'Custom event IDs must be HTML-escaped');
assert.deepEqual(english.delivery.values.map(v => v[0]), ['group:admins', 'channel:phone'], 'Delivery selector must include both groups and channels');
assert.equal(english.delivery.textvalue('sample'), 'Group: Administrators, Channel: Phone');

const chinese = await renderRules(s => s === 'WAN · Disconnected' ? 'WAN · 连接断开' : s);
chinese.setStoredEvent('wan.down');
assert.equal(chinese.event.textvalue('sample'), 'WAN · 连接断开', 'Grid label must follow LuCI language');
console.log('CatOS Notify: all event IDs display translated labels while retaining raw UCI IDs.');
})().catch(error => { console.error(error); process.exitCode = 1; });
NODE

node - <<'NODE'
globalThis.L = {resource: p => p};
globalThis.E = () => ({});
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
  return {tag, attrs, children: Array.isArray(contents) ? contents : contents == null ? [] : [contents], value: attrs.value || ''};
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
const uci = {sections: (_config, kind) => kind === 'channel' ? [{'.name':'phone',name:'Phone'}] : [{'.name':'admins',name:'Administrators'}]};
const app = Function('E', '_', 'view', 'rpc', 'ui', 'L', 'uci', source)(
  E, s => s, {extend: view => view}, rpc,
  {addNotification: (_title, content) => notifications.push(content)},
  {resource: p => p}, uci);
const tree = app.render({enabled: true, queued: 0, history: []});
assert(find(tree, n => n.tag === 'link' && n.attrs.href === 'view/catos/notify/overview.css'), 'Overview stylesheet must be loaded');
const compose = find(tree, n => n.attrs?.class === 'catos-notify-compose');
assert(compose && compose.children.length === 4, 'Composer must have three fields and one action row');
const fields = ['title', 'body'];
for (let i = 0; i < fields.length; i++) {
  const row = compose.children[i];
  assert.equal(row.attrs.class, 'catos-notify-compose-row');
  assert.equal(row.children[0].attrs.for, 'catos-notify-' + fields[i]);
  assert.equal(row.children[1].attrs.class, 'catos-notify-compose-control');
}
const groupTarget = find(compose, n => n.tag === 'input' && n.attrs?.value === 'group:admins');
const channelTarget = find(compose, n => n.tag === 'input' && n.attrs?.value === 'channel:phone');
assert(groupTarget && channelTarget, 'Manual send must offer individual channels and groups');
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
  assert.equal(sent.length, 0, 'No destination may be selected implicitly');
  groupTarget.checked = true;
  channelTarget.checked = true;
  await button.attrs.click({currentTarget: button});
  assert.deepEqual(sent, [['Test', 'Example', ['group:admins', 'channel:phone']]]);
  assert.equal(button.disabled, false, 'Send button must be re-enabled after completion');
  assert(notifications.length >= 2, 'Validation and success feedback must be shown');
  console.log('CatOS Notify: overview composer structure, responsive CSS and button flow verified.');
})().catch(error => { console.error(error); process.exitCode = 1; });
NODE

node - <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const source = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify/rules.js', 'utf8');
const variables = Function('_', source.slice(0, source.indexOf('\nreturn view.extend')) + '\nreturn templateVariables;')(s => s);
const keys = event => variables(event).map(v => v[0]);
assert(keys('auth.ssh.failed').includes('count'));
assert(!keys('auth.ssh.failed').includes('interface'));
assert(keys('health.cpu_temp.high').includes('threshold'));
assert(!keys('health.cpu_temp.high').includes('device'));
assert(keys('device.known.online').includes('ip'));
assert(!keys('public.ipv4.changed').includes('interface'));
assert(!keys('system.boot').includes('old'));
assert.deepEqual(keys('custom.event'), ['router','time','event','source','severity','body']);
assert(variables('system.summary').every(v => v.length === 2 && v[1]), 'Every variable must have a semantic label');
const overview = fs.readFileSync('luci/luci-app-catos-notify/htdocs/luci-static/resources/view/catos/notify.js', 'utf8');
let modal;
const E = (tag, attrs, children) => ({tag, attrs, children});
const ui = {showModal: (_title, contents) => {modal = contents;}, hideModal() {}};
const table = Function('E','_','ui', overview.slice(overview.indexOf('function historyTable'), overview.indexOf('\nreturn view.extend')) + '\nreturn historyTable;')(E, s => s, ui);
const tree = table([{time:1,result:'success',event:'<event>',title:'<title>',body:'<b>literal</b>\nline'}]);
const rows = tree.children.children[1].children;
assert.deepEqual(rows[0].children[1].children, ['<title>'], 'History titles must render as text nodes in LuCI');
rows[0].children[3].children.attrs.click();
assert.deepEqual(modal[3].children, ['<title>']);
assert.deepEqual(modal[5].children, ['<b>literal</b>\nline'], 'Delivery bodies must not be interpreted as HTML');
console.log('CatOS Notify: event-specific variables and literal delivery-detail text verified.');
NODE
