#!/usr/bin/env node
'use strict';

// Keep the LuCI gettext catalog synchronized with the English source text.
// --sync-template mechanically rebuilds the developer-facing POT file.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const app = path.join(root, 'luci/luci-app-catos-notify');
const ui = path.join(app, 'htdocs/luci-static/resources/view/catos');
const viewFiles = [path.join(ui, 'notify.js'),
  ...fs.readdirSync(path.join(ui, 'notify')).filter(name => name.endsWith('.js'))
    .map(name => path.join(ui, 'notify', name))];
const menu = JSON.parse(fs.readFileSync(path.join(app,
  'root/usr/share/luci/menu.d/luci-app-catos-notify.json'), 'utf8'));
const source = new Set();

for (const file of viewFiles) {
  const js = fs.readFileSync(file, 'utf8');
  for (const match of js.matchAll(/_\('((?:[^'\\]|\\.)*)'\)/g)) {
    // Source strings deliberately use simple single-quoted JS literals.
    assert(!match[1].includes('\\'), 'Escaped gettext literal needs parser update: ' + match[1]);
    source.add(match[1]);
  }
}
for (const entry of Object.values(menu)) {
  if (entry.title) source.add(entry.title);
}

const expected = [...source].sort();
const template = path.join(app, 'po/templates/catos-notify.pot');
const translations = path.join(root,
  'luci/luci-i18n-catos-notify-zh-cn/po/zh_Hans/catos-notify.po');
const header = 'msgid ""\nmsgstr ""\n' +
  '"Content-Type: text/plain; charset=UTF-8\\n"\n' +
  '"Content-Transfer-Encoding: 8bit\\n"\n';
const generated = header + '\n' + expected
  .map(value => 'msgid ' + JSON.stringify(value) + '\nmsgstr ""\n')
  .join('\n');

if (process.argv.includes('--sync-template')) {
  fs.mkdirSync(path.dirname(template), { recursive: true });
  fs.writeFileSync(template, generated);
  console.log('Updated CatOS Notify translation template (' + expected.length + ' strings).');
  process.exit(0);
}

assert.equal(fs.readFileSync(template, 'utf8'), generated,
  'POT is out of date. Run node scripts/check-notify-i18n.js --sync-template');

const po = fs.readFileSync(translations, 'utf8');
assert(po.includes('Language: zh_Hans\\n'), 'Simplified Chinese catalog has wrong locale');
const actual = new Map();
for (const match of po.matchAll(/^msgid ("(?:[^"\\]|\\.)*")\nmsgstr ("(?:[^"\\]|\\.)*")$/gm)) {
  const id = JSON.parse(match[1]);
  const translated = JSON.parse(match[2]);
  if (!id) continue;
  assert(!actual.has(id), 'Duplicate translation: ' + id);
  assert(translated.trim(), 'Empty Chinese translation: ' + id);
  actual.set(id, translated);
}
for (const id of expected) assert(actual.has(id), 'Missing Chinese translation: ' + id);
for (const id of actual.keys()) assert(source.has(id), 'Unused Chinese translation: ' + id);
console.log('CatOS Notify: ' + expected.length + ' English UI/menu strings have Simplified Chinese translations.');
