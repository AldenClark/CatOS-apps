'use strict';
'require view';
'require form';
'require rpc';
'require ui';

var getStatus = rpc.declare({
	object: 'catos.notify',
	method: 'status',
	expect: { '': {} }
});

var sendTest = rpc.declare({
	object: 'catos.notify',
	method: 'test',
	params: [ 'channel', 'title', 'body' ],
	expect: { '': {} }
});

var sendMessage = rpc.declare({
	object: 'catos.notify',
	method: 'send',
	params: [ 'title', 'body', 'group' ],
	expect: { '': {} }
});

var sendTemplate = rpc.declare({
	object: 'catos.notify',
	method: 'send',
	params: [ 'title', 'body', 'group', 'template', 'data' ],
	expect: { '': {} }
});

var newToken = rpc.declare({
	object: 'catos.notify',
	method: 'token',
	expect: { '': {} }
});

var events = [
	[ 'wan.down', _('WAN disconnected') ],
	[ 'wan.up', _('WAN restored') ],
	[ 'wan.ipv4.changed', _('WAN IPv4 changed') ],
	[ 'wan.ipv6.changed', _('WAN IPv6 changed') ],
	[ 'wan.prefix.changed', _('Delegated IPv6 prefix changed') ],
	[ 'public.ipv4.changed', _('Public IPv4 changed') ],
	[ 'public.ipv6.changed', _('Public IPv6 changed') ],
	[ 'wan.primary.changed', _('Primary WAN changed') ],
	[ 'device.unknown.online', _('Unknown device detected') ],
	[ 'device.known.online', _('Monitored device online') ],
	[ 'device.known.offline', _('Monitored device offline') ],
	[ 'auth.ssh.failed', _('Repeated SSH authentication failures') ],
	[ 'auth.luci.failed', _('Repeated LuCI authentication failures') ],
	[ 'system.boot', _('Startup complete') ],
	[ 'system.reboot', _('Reboot or shutdown initiated') ],
	[ 'health.cpu_temp.high', _('High CPU temperature') ],
	[ 'health.load.high', _('High system load') ],
	[ 'health.memory.high', _('Low available memory') ],
	[ 'health.storage.low', _('Low free storage') ],
	[ 'system.summary', _('Periodic status summary') ]
];

function notificationResult(result, success) {
	var ok = result && (result.ok === true || result.ok === 1);
	ui.addNotification(null, E('p', {}, ok ? success : _('Operation failed: ') + (result && result.message || _('Unknown error'))), ok ? 'info' : 'danger');
}

return view.extend({
	load: function() {
		return getStatus().catch(function() { return {}; });
	},

	render: function(status) {
		var m = new form.Map('catos_notify', _('CatOS Notify'),
			_('Notification channels, event rules, message templates and optional HTTP reception. The service runs without LuCI.'));
		var s, o;

		s = m.section(form.NamedSection, 'main', 'settings', _('Service settings'));
		s.addremove = false;
		s.tab('general', _('General'));
		s.tab('monitor', _('Monitoring'));
		s.tab('receiver', _('HTTP receiver'));

		o = s.taboption('general', form.Flag, 'enabled', _('Enable notification service'));
		o.default = '0';
		o = s.taboption('general', form.Value, 'router_name', _('Router name'));
		o.default = 'OpenWrt';
		o = s.taboption('general', form.Value, 'queue_limit', _('Maximum queued deliveries'));
		o.default = '64';
		o.datatype = 'range(1,512)';
		o = s.taboption('general', form.Value, 'request_timeout', _('Provider request timeout (seconds)'));
		o.datatype = 'range(3,60)';
		o.default = '12';
		o = s.taboption('general', form.Value, 'retry_limit', _('Maximum delivery attempts'));
		o.datatype = 'range(1,10)';
		o.default = '3';

		o = s.taboption('monitor', form.Value, 'wan_interfaces', _('WAN network interfaces'));
		o.description = _('Space-separated netifd interface names, for example: wan wan6');
		o.default = 'wan wan6';
		o = s.taboption('monitor', form.Value, 'device_interface', _('LAN device for discovery'));
		o.default = 'br-lan';
		o = s.taboption('monitor', form.Flag, 'discover_devices', _('Discover unknown connected devices'));
		o.default = '1';
		o = s.taboption('monitor', form.Value, 'monitor_interval', _('System scan interval (seconds)'));
		o.datatype = 'range(10,600)';
		o.default = '30';
		o = s.taboption('monitor', form.Value, 'known_probe_interval', _('Known device probe interval (seconds)'));
		o.datatype = 'range(15,3600)';
		o.default = '60';
		o = s.taboption('monitor', form.Flag, 'public_ip_enabled', _('Check public IPv4/IPv6 using external services'));
		o.default = '1';
		o = s.taboption('monitor', form.Value, 'public_ip_interval', _('Public IP check interval (seconds)'));
		o.datatype = 'range(60,86400)';
		o.default = '900';
		o.description = _('Uses external IP lookup services. Disable external address monitoring by disabling its event rules.');
		o = s.taboption('monitor', form.Value, 'summary_interval', _('Status summary interval (seconds)'));
		o.datatype = 'range(300,604800)';
		o.default = '86400';
		o = s.taboption('monitor', form.Value, 'auth_failures', _('Failed login threshold'));
		o.datatype = 'range(2,100)';
		o.default = '5';
		o = s.taboption('monitor', form.Value, 'auth_window', _('Failed login time window (seconds)'));
		o.datatype = 'range(30,86400)';
		o.default = '600';
		o = s.taboption('monitor', form.Value, 'cpu_temperature', _('CPU temperature warning (°C)'));
		o.datatype = 'range(1,150)';
		o.default = '80';
		o = s.taboption('monitor', form.Value, 'load_threshold', _('Load warning threshold'));
		o.datatype = 'range(1,128)';
		o.default = '4';
		o = s.taboption('monitor', form.Value, 'memory_available_mb', _('Minimum available memory (MiB)'));
		o.datatype = 'range(1,32768)';
		o.default = '32';
		o = s.taboption('monitor', form.Value, 'storage_available_mb', _('Minimum free storage (MiB)'));
		o.datatype = 'range(1,65536)';
		o.default = '32';
		o = s.taboption('monitor', form.Value, 'storage_mount', _('Storage mountpoint'));
		o.default = '/';

		o = s.taboption('receiver', form.Flag, 'receiver_enabled', _('Enable HTTP message receiver'));
		o.default = '0';
		o.description = _('Off by default. HTTP POST endpoint: /cgi-bin/catos-notify. Requires an existing uhttpd installation.');
		o = s.taboption('receiver', form.ListValue, 'receiver_scope', _('Allowed source'));
		o.value('lan', _('LAN only'));
		o.value('external', _('External access (HTTPS and authentication required)'));
		o.default = 'lan';
		o = s.taboption('receiver', form.Flag, 'receiver_auth', _('Require authorization'));
		o.default = '1';
		o.description = _('Optional for LAN access. External access always requires authentication regardless of this setting.');
		o = s.taboption('receiver', form.Value, 'receiver_token', _('Receiver token'));
		o.password = true;
		o.description = _('Send this secret as the X-CatOS-Token request header. Generate a random token before enabling reception.');
		o = s.taboption('receiver', form.Value, 'receiver_lan_interfaces', _('Allowed LAN devices'));
		o.placeholder = 'br-lan';
		o.description = _('Space-separated routing device names. Empty uses the configured LAN discovery device.');
		o = s.taboption('receiver', form.Value, 'receiver_rate_limit', _('Requests per minute per IP'));
		o.datatype = 'range(1,120)';
		o.default = '30';
		o = s.taboption('receiver', form.Button, '_regenerate', _('Generate new receiver token'));
		o.inputstyle = 'action';
		o.onclick = function() {
			return newToken().then(function(result) {
				notificationResult(result, _('Token generated. Reload the page to view the updated configuration.'));
			});
		};

		s = m.section(form.GridSection, 'channel', _('Notification channels'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Add multiple instances of any supported provider. Every channel can belong to a delivery group.');
		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o = s.option(form.Value, 'name', _('Name'));
		o.rmempty = false;
		o = s.option(form.ListValue, 'type', _('Provider'));
		[
			[ 'bark', 'Bark' ], [ 'pushgo', 'PushGo' ], [ 'ntfy', 'ntfy' ],
			[ 'feishu', _('Feishu') ], [ 'dingtalk', _('DingTalk') ],
			[ 'wecom', _('WeCom') ], [ 'telegram', 'Telegram' ],
			[ 'webhook', _('Generic Webhook') ]
		].forEach(function(type) { o.value(type[0], type[1]); });
		o.rmempty = false;
		o = s.option(form.Value, 'group', _('Delivery group'));
		o.default = 'default';
		o = s.option(form.Value, 'url', _('Server / webhook URL'));
		o.modalonly = true;
		o.description = _('Leave empty only when the provider has a built-in server. Use HTTPS for public endpoints.');
		o = s.option(form.Value, 'key', _('Bark device / WeCom key'));
		o.modalonly = true;
		o.password = true;
		o.depends('type', 'bark');
		o.depends('type', 'wecom');
		o = s.option(form.Value, 'channel_id', _('PushGo channel ID'));
		o.modalonly = true;
		o.depends('type', 'pushgo');
		o = s.option(form.Value, 'password', _('PushGo channel password'));
		o.modalonly = true;
		o.password = true;
		o.depends('type', 'pushgo');
		o = s.option(form.Value, 'topic', _('ntfy topic'));
		o.modalonly = true;
		o.depends('type', 'ntfy');
		o = s.option(form.Value, 'chat_id', _('Telegram chat ID'));
		o.modalonly = true;
		o.depends('type', 'telegram');
		o = s.option(form.Value, 'token', _('Bot token / API bearer token'));
		o.modalonly = true;
		o.password = true;
		o.depends('type', 'telegram');
		o.depends('type', 'pushgo');
		o.depends('type', 'ntfy');
		o.depends('type', 'webhook');
		o = s.option(form.Value, 'secret', _('Webhook signing secret'));
		o.modalonly = true;
		o.password = true;
		o.depends('type', 'feishu');
		o.depends('type', 'dingtalk');
		o = s.option(form.Value, 'header_name', _('Custom header name'));
		o.modalonly = true;
		o.depends('type', 'webhook');
		o = s.option(form.Value, 'header_value', _('Custom header value'));
		o.modalonly = true;
		o.password = true;
		o.depends('type', 'webhook');
		o = s.option(form.Button, '_test', _('Test'));
		o.inputstyle = 'apply';
		o.onclick = function(ev, sectionId) {
			return sendTest(sectionId, 'CatOS Notify test', 'This is a test notification.').then(function(result) {
				notificationResult(result, _('Test notification delivered.'));
			});
		};

		s = m.section(form.GridSection, 'rule', _('Event routing rules'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Rules route matching events to channel groups. Disable a rule to suppress the corresponding notification.');
		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o = s.option(form.Value, 'event', _('Event ID'));
		events.forEach(function(item) { o.value(item[0], item[1]); });
		o.rmempty = false;
		o.description = _('Choose a built-in event or enter a custom event ID from another installed package.');
		o = s.option(form.Value, 'group', _('Delivery group'));
		o.default = 'default';
		o = s.option(form.Value, 'template', _('Template ID'));
		o.default = 'default';
		o = s.option(form.Value, 'interface', _('Interface filter'));
		o.modalonly = true;
		o = s.option(form.Value, 'source', _('Source filter'));
		o.modalonly = true;
		o = s.option(form.Value, 'device', _('Device MAC filter'));
		o.modalonly = true;
		o = s.option(form.ListValue, 'severity', _('Override severity'));
		o.modalonly = true;
		o.value('inherit', _('Keep source severity'));
		o.value('low', _('Low'));
		o.value('normal', _('Normal'));
		o.value('high', _('High'));
		o.value('critical', _('Critical'));
		o.default = 'inherit';
		o = s.option(form.Value, 'cooldown', _('Cooldown (seconds)'));
		o.datatype = 'uinteger';
		o.default = '60';

		s = m.section(form.GridSection, 'template', _('Message templates'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Template variables include {{router}}, {{event}}, {{time}}, {{body}}, {{old}}, {{new}}, {{interface}}, and data fields from an external caller.');
		o = s.option(form.Value, 'name', _('Name'));
		o = s.option(form.Value, 'title', _('Title'));
		o.rmempty = false;
		o = s.option(form.TextValue, 'body', _('Body'));
		o.rows = 5;
		o.rmempty = false;
		o = s.option(form.Button, '_test', _('Test template'));
		o.inputstyle = 'apply';
		o.onclick = function(ev, sectionId) {
			return sendTemplate('', '', 'default', sectionId, {
				interface: 'wan', device: 'aa:bb:cc:dd:ee:ff',
				old: '192.0.2.10', new: '192.0.2.11'
			}).then(function(result) {
				notificationResult(result, _('Rendered template queued for delivery to the default group.'));
			});
		};

		s = m.section(form.GridSection, 'device', _('Known monitored devices'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Register known devices. An IP address is required for online/offline probing; repeated failed probes are debounced.');
		o = s.option(form.Flag, 'monitor', _('Monitor'));
		o.default = '1';
		o = s.option(form.Value, 'name', _('Device name'));
		o = s.option(form.Value, 'mac', _('MAC address'));
		o.datatype = 'macaddr';
		o = s.option(form.Value, 'ip', _('Probe IP address'));
		o.datatype = 'ipaddr';

		var details = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Status and quick message')),
			E('p', {}, _('Queued deliveries: ') + (status.queued || 0)),
			E('p', {}, status.enabled ? _('Service enabled') : _('Service disabled')),
			E('button', {
				'class': 'btn cbi-button cbi-button-action',
				'click': function(ev) {
					var title = document.getElementById('catos-quick-title').value;
					var body = document.getElementById('catos-quick-body').value;
					var group = document.getElementById('catos-quick-group').value;
					return sendMessage(title, body, group).then(function(result) {
						notificationResult(result, _('Message added to the delivery queue.'));
					});
				}
			}, _('Queue message')),
			E('input', { 'id': 'catos-quick-title', 'class': 'cbi-input-text', 'placeholder': _('Title') }),
			E('input', { 'id': 'catos-quick-body', 'class': 'cbi-input-text', 'placeholder': _('Body') }),
			E('input', { 'id': 'catos-quick-group', 'class': 'cbi-input-text', 'value': 'default', 'placeholder': _('Delivery group') }),
			E('h4', {}, _('Recent delivery history')),
			E('pre', {}, (status.history || []).join('\n') || _('No delivery records yet.'))
		]);

		return m.render().then(function(map) {
			return E('div', {}, [ details, map ]);
		});
	}
});
