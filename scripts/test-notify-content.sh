#!/usr/bin/env bash
# Execute the real JSON/template/history functions using OpenWrt libubox jshn.
# On a host: JSHN_LIB=/path/to/libubox/sh/jshn.sh PATH=/path/to/jshn:$PATH bash scripts/test-notify-content.sh
set -eo pipefail
cd "$(dirname "$0")/.."
source "${JSHN_LIB:-/usr/share/libubox/jshn.sh}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
RUN="$work"
core=net/catos-notify/files/catos-notify-dispatch
for fn in history show_status replace_variable render_template; do
 eval "$(sed -n "/^$fn() {/,/^}/p" "$core")"
done
init_run() { mkdir -p "$RUN/queue"; }
setting() { printf '%s' "$2"; }
init_run
TITLE='A | "quoted" <title>'
BODY=$'first line\n第二行 | <script>literal</script>\n\n'
history phone success wan.ipv4.changed "$TITLE" "$BODY"
history phone failed test "$TITLE" "$BODY"
show_status > "$work/status.json"
node - "$work/status.json" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const status = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
assert.equal(status.history.length, 2);
assert.equal(status.history[0].event, 'wan.ipv4.changed');
assert.equal(status.history[1].result, 'failed');
assert.equal(status.history[0].title, 'A | "quoted" <title>');
assert.equal(status.history[0].body, 'first line\n第二行 | <script>literal</script>\n\n');
assert.equal(status.queued, 0);
NODE
for i in $(seq 1 105); do history phone success test "$TITLE" "$BODY"; done
[ "$(wc -l < "$RUN/history.jsonl")" -le 100 ]
show_status > "$work/status.json"
node - "$work/status.json" <<'NODE'
const assert = require('node:assert/strict');
const status = require(process.argv[2]);
assert.equal(status.history.length, 20);
assert(status.history.every(r => r.body.endsWith('\n\n')));
NODE
INPUT='{"event":"auth.ssh.failed","body":"source details","data":{"count":"7","window":"600","origin":"192.0.2.4"}}'
[ "$(render_template '{{count}} / {{window}} / {{origin}} / {{body}} / {{unknown}}')" = '7 / 600 / 192.0.2.4 / source details / {{unknown}}' ]
# Exercise publisher JSON too, replacing only the final external CLI invocation.
emitter=$(sed -n '/^emit() {/,/^}/p' net/catos-notify/files/catos-notify-monitor)
eval "${emitter/\/usr\/bin\/catos-notify publish/cat > \"\$RUN\/event.json\"}"
emit health.cpu_temp.high details '' '' 91 high '' threshold 80
INPUT=$(cat "$RUN/event.json")
[ "$(render_template '{{value}} / {{threshold}}')" = '91 / 80' ]
emit auth.ssh.failed details '' '' 7 high '' window 600 origin 192.0.2.4
INPUT=$(cat "$RUN/event.json")
[ "$(render_template '{{count}} / {{window}} / {{origin}}')" = '7 / 600 / 192.0.2.4' ]
emit device.known.online details '' offline online normal aa:bb:cc:dd:ee:ff device_name 'My device' ip 192.0.2.5
INPUT=$(cat "$RUN/event.json")
[ "$(render_template '{{device_name}} / {{ip}} / {{device}}')" = 'My device / 192.0.2.5 / aa:bb:cc:dd:ee:ff' ]
printf 'Notify content: exact JSON history, bounds, status and semantic event templates passed.\n'
