#!/bin/sh
# Opt-in uhttpd CGI endpoint: POST /cgi-bin/catos-notify
umask 077
PATH=/usr/sbin:/usr/bin:/sbin:/bin
RUN=/tmp/catos-notify
mkdir -p "$RUN/receiver" 2>/dev/null

respond() {
	printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n' "$1"
	printf '%s\n' "$2"
	exit 0
}

setting() {
	uci -q get "catos_notify.main.$1" 2>/dev/null || printf '%s' "$2"
}

valid_source() {
	local client="${REMOTE_ADDR:-}" route iface allowed
	[ -n "$client" ] || return 1
	case "$client" in *[!a-fA-F0-9:.]*|''|*[!0-9a-fA-F:.]*) return 1 ;; esac
	route="$(ip route get "$client" 2>/dev/null)" || return 1
	set -- $route
	iface=
	while [ "$#" -gt 1 ]; do
		if [ "$1" = dev ]; then iface="$2"; break; fi
		shift
	done
	[ -n "$iface" ] || return 1
	for allowed in $(setting receiver_lan_interfaces "$(setting device_interface br-lan)"); do
		[ "$iface" = "$allowed" ] && return 0
	done
	return 1
}

[ "$(setting enabled 0)" = 1 ] || respond '503 Service Unavailable' '{"ok":false,"message":"disabled"}'
[ "$(setting receiver_enabled 0)" = 1 ] || respond '404 Not Found' '{"ok":false,"message":"disabled"}'
[ "${REQUEST_METHOD:-}" = POST ] || respond '405 Method Not Allowed' '{"ok":false,"message":"method_not_allowed"}'
case "${CONTENT_TYPE:-}" in application/json|application/json\;*) ;; *)
	respond '415 Unsupported Media Type' '{"ok":false,"message":"json_required"}' ;;
esac
case "${CONTENT_LENGTH:-}" in ''|*[!0-9]*) respond '411 Length Required' '{"ok":false,"message":"length_required"}' ;; esac
[ "$CONTENT_LENGTH" -gt 0 ] && [ "$CONTENT_LENGTH" -le 16384 ] ||
	respond '413 Payload Too Large' '{"ok":false,"message":"payload_too_large"}'

scope="$(setting receiver_scope lan)"
auth="$(setting receiver_auth 1)"
case "$scope" in
	lan)
		valid_source || respond '403 Forbidden' '{"ok":false,"message":"source_forbidden"}'
		;;
	external)
		# Never widen LuCI/uhttpd firewall exposure automatically.
		# Only direct TLS CGI sessions are accepted in external mode.
		case "${HTTPS:-}" in
			on|1|true) ;;
			*) respond '403 Forbidden' '{"ok":false,"message":"https_required"}' ;;
		esac
		auth=1
		;;
	*) respond '403 Forbidden' '{"ok":false,"message":"scope_invalid"}' ;;
esac

# Bound unauthenticated work without allocating a bucket per unknown client.
# This global cap is deliberately conservative for low-memory routers.
window="$(date +%s)"
window=$((window / 60))
mkdir "$RUN/receiver-global.lock" 2>/dev/null ||
	respond '429 Too Many Requests' '{"ok":false,"message":"rate_limited"}'
trap 'rmdir "$RUN/receiver-global.lock" 2>/dev/null' EXIT
global="$(cat "$RUN/receiver-global" 2>/dev/null)"
global_window="${global%% *}"
global_count="${global#* }"
[ "$global_window" = "$window" ] || global_count=0
case "$global_count" in ''|*[!0-9]*) global_count=0 ;; esac
[ "$global_count" -lt 300 ] || respond '429 Too Many Requests' '{"ok":false,"message":"rate_limited"}'
printf '%s %s' "$window" "$((global_count + 1))" > "$RUN/receiver-global"
rmdir "$RUN/receiver-global.lock" 2>/dev/null || true
trap - EXIT

if [ "$auth" = 1 ]; then
	expected="$(setting receiver_token '')"
	actual="${HTTP_X_CATOS_TOKEN:-}"
	[ "${#expected}" -ge 32 ] && [ "${#actual}" -ge 32 ] ||
		respond '401 Unauthorized' '{"ok":false,"message":"unauthorized"}'
	# Compare digests of fixed length instead of short-circuit plaintext strings.
	a="$(printf '%s' "$expected" | openssl dgst -sha256 2>/dev/null)"
	b="$(printf '%s' "$actual" | openssl dgst -sha256 2>/dev/null)"
	[ -n "$a" ] && [ "$a" = "$b" ] ||
		respond '401 Unauthorized' '{"ok":false,"message":"unauthorized"}'
fi

rate="$(setting receiver_rate_limit 30)"
case "$rate" in ''|*[!0-9]*) rate=30 ;; esac
[ "$rate" -ge 1 ] && [ "$rate" -le 120 ] || rate=30
client_hash="$(printf '%s' "${REMOTE_ADDR:-unknown}" | cksum | awk '{print $1}')"
bucket="$RUN/receiver/$client_hash"
mkdir "$bucket.lock" 2>/dev/null ||
	respond '429 Too Many Requests' '{"ok":false,"message":"rate_limited"}'
trap 'rmdir "$bucket.lock" 2>/dev/null' EXIT
stored="$(cat "$bucket" 2>/dev/null)"
stored_window="${stored%% *}"
count="${stored#* }"
[ "$stored_window" = "$window" ] || count=0
case "$count" in ''|*[!0-9]*) count=0 ;; esac
[ "$count" -lt "$rate" ] || respond '429 Too Many Requests' '{"ok":false,"message":"rate_limited"}'
printf '%s %s' "$window" "$((count + 1))" > "$bucket"
rmdir "$bucket.lock" 2>/dev/null || true
trap - EXIT

payload="$(head -c "$CONTENT_LENGTH")"
# External callers only use the immediate-message interface; event injection
# and destination URL overrides are never accepted by this endpoint.
case "$payload" in '') respond '400 Bad Request' '{"ok":false,"message":"empty_request"}' ;; esac
result="$(printf '%s' "$payload" | /usr/bin/catos-notify send 2>/dev/null)"
case "$result" in *'"ok": true'*|*'"ok":true'*)
	respond '202 Accepted' "$result" ;;
	*) respond '400 Bad Request' '{"ok":false,"message":"invalid_message"}' ;;
esac
