# CatOS Notify

CatOS Notify is a lightweight OpenWrt notification service. It can be installed without LuCI, while `luci-app-catos-notify` adds a configuration interface under **Services → CatOS Notify**.

## Features

- Delivery to Bark, PushGo, ntfy, Feishu, DingTalk group robots, WeCom, Telegram and generic JSON webhooks.
- Multiple channel instances, independently managed delivery groups, per-event templates and event routing rules.
- WAN state, IPv4/IPv6 and delegated prefixes, public addresses, single-primary WAN failover, known and unknown devices, SSH/LuCI authentication failures, boot/shutdown, system resource thresholds and periodic summaries.
- Local command-line and ubus methods for other applications.
- An HTTP message receiver that is **disabled by default** and never modifies firewall policy.

This is an early implementation. Test it on the target OpenWrt release and hardware before using it for important alerts.

## Configure and start

1. Install `catos-notify` and optionally `luci-app-catos-notify`. To display Simplified Chinese when selected in LuCI, also install `luci-i18n-catos-notify-zh-cn` (English needs no additional package).
2. Create at least one `channel` in LuCI or `/etc/config/catos_notify`. Test it under **Channels** after saving changes (the test also works while the channel is disabled).
3. Optionally create **Delivery groups** and explicitly add channels as members. A channel can belong to multiple groups.
4. In the channel editor, **Send test** sends a fixed test notification using saved credentials. Save & Apply edited credentials first; testing also works for disabled channels.
5. Under **Event rules**, choose one or more channels and/or groups under **Delivery** and edit that rule's title/body template. No channel or rule has an implicit delivery group.
5. Under **Settings → Service**, enable the service and click **Save & Apply**.

The LuCI interface is organized into **Overview** (status, recent deliveries and manual messages), **Channels**, **Delivery groups**, **Event rules** (including each event's template), **Monitored devices**, and **Settings** (service, network, login, resource and HTTP receiver settings). Each page works with the same `/etc/config/catos_notify` configuration; the core service also works without LuCI.

From an SSH session:

```sh
uci set catos_notify.main.enabled='1'
uci commit catos_notify
/etc/init.d/catos-notify enable
/etc/init.d/catos-notify restart
```

Runtime state, delivery queue, deduplication and history are in `/tmp/catos-notify`. Credentials are held in `/etc/config/catos_notify`, which is restricted to root (`0600`).

## Call from another package

Send an immediate message to explicit destination references (named UCI section IDs):

```sh
printf '%s\n' '{"title":"DDNS","body":"A DNS record was updated","targets":["channel:phone","group:admins"]}' |
  catos-notify send
```

Publish a structured event and let `rule` sections decide where it goes:

```sh
printf '%s\n' '{"source":"catos-ddns","event":"ddns.updated","title":"DDNS update","body":"Home address changed","severity":"normal","data":{"hostname":"home.example.net"}}' |
  catos-notify publish
```

The corresponding LuCI event rule must use the exact event name `ddns.updated`, select at least one channel or group under **Delivery**, and define a title/body template. A single channel selected both directly and via multiple groups receives one queued message per matching rule. A disabled channel is excluded from normal deliveries; an individual test is still allowed. Notification routing is asynchronous; a successful enqueue response does not mean the remote provider has already delivered the message.

For a rule's templates, the service substitutes literal `{{router}}`, `{{event}}`, `{{time}}`, `{{body}}`, `{{source}}`, `{{severity}}`, `{{interface}}`, `{{device}}`, `{{old}}`, `{{new}}`, and flat fields from `data`/`variables`. Unknown placeholders remain literal. Templates are not shared between rules. The title and body editors show clickable variables with semantic labels; insertion replaces the selection or inserts at the cursor. Changing the event refreshes those variable choices without rewriting the template.

The common editor variables are `router`, `time`, `event`, `source`, `severity`, and `body`. Built-in event variables reflect the publisher payload:

| Event | Additional editor variables |
| --- | --- |
| WAN up/down | `interface` |
| WAN IPv4/IPv6/prefix change | `interface`, `old`, `new` (addresses/prefixes in CIDR notation) |
| Public IPv4/IPv6 change | `old`, `new` (public address) |
| Primary WAN change | `old`, `new` (default-route device) |
| Unknown device | `device` (MAC), `interface` (discovery bridge) |
| Known device online/offline | `device` (MAC if configured), `device_name`, `ip` (probe address) |
| SSH/LuCI login failures | `count`, `window` (seconds), `origin` (last source IP if available) |
| CPU temperature/load/memory/storage alert | `value`, `threshold` (°C, 1-minute load, or MiB); storage also provides `mount` |
| Boot/shutdown | Common variables only |
| Periodic summary | `uptime` (seconds), `load` (1/5/15 minutes), `memory`, `storage` (MiB), `addresses` |

Custom publishers define their own flat `data` keys; the editor lists common variables and explains the `{{key}}` syntax. Existing `old`/`new` templates remain supported by the renderer.

Recent delivery history shows time, message title, result and a content-details action. Details include the original event ID and the exact rendered title/body, displayed as plain text. The internal channel ID is omitted. The core stores bounded JSON Lines in `/tmp/catos-notify/history.jsonl` (up to 100 attempts, trimmed to 80; status returns the latest 20), including failed retries, exhausted deliveries, queue-full attempts and manual tests. Previous metadata-only history cannot recover message content.

The service also registers the `catos.notify` ubus object with `send`, `publish`, `test`, `status` and `token` methods. Methods exposed to LuCI are restricted by the package's rpcd ACL. Third-party packages should use the CLI as root or set their own appropriate ubus ACLs.

## Configuration reference

| UCI section | Purpose | Important fields |
| --- | --- | --- |
| `settings main` | Service and monitor | `enabled`, intervals, thresholds, receiver settings |
| `channel 'phone'` | Named delivery destination | `type`, `name`, `enabled`, provider credentials |
| `group 'admins'` | Named collection of channels | `name`, repeated `list channels 'phone'` |
| `rule` | Event subscription, destination selection and its own template | `event`, repeated `list targets 'channel:phone'` / `list targets 'group:admins'`, `title`, `body`, `cooldown`, optional filters |
| `device` | Known LAN device | `name`, `mac`, `ip`, `monitor` |

Channel and group UCI section names are stable IDs (no spaces, use letters, digits, `_` or `-`); LuCI generates these automatically. Removing a channel does not renumber another channel's references. Deleted destination IDs remain visibly marked as missing in the rule/group editors until removed. No default group, fallback group, or shared template exists. The eight provider identifiers are `bark`, `pushgo`, `ntfy`, `feishu`, `dingtalk`, `wecom`, `telegram`, and `webhook`.

| Provider | Fields |
| --- | --- |
| Bark | `key`, optional `url` (defaults to `https://api.day.app`) |
| PushGo | `channel_id`, `password`, optional `url`, optional gateway Bearer `token` |
| ntfy | `topic`, optional `url`, optional Bearer `token` |
| Feishu | `url` webhook, optional `secret` for signed requests |
| DingTalk | `url` group-robot webhook, optional `secret` for signed requests |
| WeCom | `key` or full `url` group-robot webhook |
| Telegram | Bot `token` and `chat_id` |
| Webhook | Fixed `url`, optional Bearer `token` or static `header_name` / `header_value` |

Messages are sent as JSON. Provider HTTP responses and applicable application error codes are checked. Channel credentials never need to be passed in message requests.

## HTTP message receiver

The optional receiver uses the existing uhttpd CGI route:

```text
POST https://router.example.net/cgi-bin/catos-notify
Content-Type: application/json
X-CatOS-Token: <random secret>
```

Example JSON:

```json
{"title":"UPS","body":"Battery is low","targets":["group:admins"]}
```

Before use, enable `receiver_enabled` and generate a token with the LuCI button or `catos-notify token`. `receiver_scope=lan` requires the client's actual route to use a configured LAN device. The `receiver_auth` option may be disabled **only for LAN scope**. With `receiver_scope=external`, TLS and authentication are always enforced even if `receiver_auth=0`.

No firewall rule or WAN port is opened automatically. Exposing an existing uhttpd listener to the internet can also expose other pages, including LuCI. Prefer a dedicated HTTPS reverse proxy, VPN or separate tightly scoped listener; the CGI endpoint itself does not create a new listener. Reverse proxies terminating TLS before an unencrypted CGI hop require a separate deployment review, since the receiver checks its own HTTPS connection, not untrusted forwarded headers.

The receiver accepts **immediate messages**, not arbitrary URLs or forged system events. The request body is limited to 16 KiB and the source is rate-limited. Keep the Token secret and rotate it when needed.

## Monitoring accuracy and resource use

- WAN logical status comes from netifd. The primary-route detector reports only an unambiguous default IPv4 route and does not claim to identify a unique primary in mwan3 load-sharing policies.
- Public-address detection uses external lookup services, may be unavailable offline and can be disabled with `public_ip_enabled=0` in installations where external probes are undesirable.
- Unknown device detection uses existing neighbor entries; it does not scan the LAN. The first scan after boot establishes a baseline.
- Known devices are probed by configured IP; ICMP-blocking devices require a suitable reachable probe target. A transition requires multiple observations.
- Authentication-failure parsing depends on the installed LuCI/Dropbear version and should be verified with the device's syslog.
- Shutdown alerts are best-effort and may fail if connectivity is already lost. Notification queues and history are deliberately bounded and stored in tmpfs, not durable delivery guarantees.

For a complete functional scope and acceptance checklist, see the [Notify requirements](notify-requirements.zh-CN.md).

### Content regression check

On OpenWrt (with Node available for assertions), or a host with libubox `jshn` built:

```sh
JSHN_LIB=/path/to/libubox/sh/jshn.sh PATH=/path/to/jshn:$PATH bash scripts/test-notify-content.sh
```

This exercises the actual shell history, status, publisher and template helpers. It verifies newline/Unicode/delimiter preservation, bounded history and semantic event data without sending provider requests.
