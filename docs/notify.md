# CatOS Notify

CatOS Notify is a lightweight OpenWrt notification service. It can be installed without LuCI, while `luci-app-catos-notify` adds a configuration interface under **Services → CatOS Notify**.

## Features

- Delivery to Bark, PushGo, ntfy, Feishu, DingTalk group robots, WeCom, Telegram and generic JSON webhooks.
- Multiple channel instances, delivery groups, editable notification templates and event routing rules.
- WAN state, IPv4/IPv6 and delegated prefixes, public addresses, single-primary WAN failover, known and unknown devices, SSH/LuCI authentication failures, boot/shutdown, system resource thresholds and periodic summaries.
- Local command-line and ubus methods for other applications.
- An HTTP message receiver that is **disabled by default** and never modifies firewall policy.

This is an early implementation. Test it on the target OpenWrt release and hardware before using it for important alerts.

## Configure and start

1. Install `catos-notify` and optionally `luci-app-catos-notify`. To display Simplified Chinese when selected in LuCI, also install `luci-i18n-catos-notify-zh-cn` (English needs no additional package).
2. Create at least one enabled `channel` in LuCI or `/etc/config/catos_notify`. Set its `group` (default: `default`).
3. Under **Settings → Service**, enable the service and click **Save & Apply**.
4. Under **Channels**, test the destination. Save channel changes before sending a test.

The LuCI interface is organized into **Overview** (status, recent deliveries and manual messages), **Channels**, **Event rules**, **Templates**, **Monitored devices**, and **Settings** (service, network, login, resource and HTTP receiver settings). Each page works with the same `/etc/config/catos_notify` configuration; the core service also works without LuCI.

From an SSH session:

```sh
uci set catos_notify.main.enabled='1'
uci commit catos_notify
/etc/init.d/catos-notify enable
/etc/init.d/catos-notify restart
```

Runtime state, delivery queue, deduplication and history are in `/tmp/catos-notify`. Credentials are held in `/etc/config/catos_notify`, which is restricted to root (`0600`).

## Call from another package

Send an immediate message to the configured `default` group:

```sh
printf '%s\n' '{"title":"DDNS","body":"A DNS record was updated","group":"default"}' |
  catos-notify send
```

Publish a structured event and let `rule` sections decide where it goes:

```sh
printf '%s\n' '{"source":"catos-ddns","event":"ddns.updated","title":"DDNS update","body":"Home address changed","severity":"normal","data":{"hostname":"home.example.net"}}' |
  catos-notify publish
```

The corresponding LuCI event rule must use the exact event name `ddns.updated` and an enabled target group. Notification routing is asynchronous; a successful enqueue response does not mean the remote provider has already delivered the message.

The service also registers the `catos.notify` ubus object with `send`, `publish`, `test`, `status` and `token` methods. Methods exposed to LuCI are restricted by the package's rpcd ACL. Third-party packages should use the CLI as root or set their own appropriate ubus ACLs.

## Configuration reference

| UCI section | Purpose | Important fields |
| --- | --- | --- |
| `settings main` | Service and monitor | `enabled`, intervals, thresholds, receiver settings |
| `channel` | Delivery destination | `type`, `name`, `group`, `enabled`, provider credentials |
| `rule` | Event subscription | `event`, `group`, `template`, `cooldown`, optional `interface` / `source` |
| `template` | Safe text template | `title`, `body` with literal `{{name}}` substitution |
| `device` | Known LAN device | `name`, `mac`, `ip`, `monitor` |

The eight provider identifiers are `bark`, `pushgo`, `ntfy`, `feishu`, `dingtalk`, `wecom`, `telegram`, and `webhook`.

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
{"title":"UPS","body":"Battery is low","group":"default"}
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
