'use strict';
'require view';
'require form';
'require rpc';
'require ui';

var generateToken = rpc.declare({
	object: 'catos.notify',
	method: 'token',
	expect: { '': {} }
});

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Settings'),
			_('Control service operation, event collection, resource thresholds and the optional HTTP receiver.'));
		var s = m.section(form.NamedSection, 'main', 'settings', _('Notify service'));
		s.addremove = false;
		s.tab('service', _('Service'));
		s.tab('network', _('Network monitoring'));
		s.tab('security', _('Login monitoring'));
		s.tab('health', _('Resource alerts'));
		s.tab('receiver', _('HTTP receiver'));

		var o = s.taboption('service', form.Flag, 'enabled', _('Enable notification service'));
		o.default = '0';
		o.description = _('You must also configure at least one enabled delivery channel and a matching event rule.');
		o = s.taboption('service', form.Value, 'router_name', _('Router name'));
		o.default = 'OpenWrt';
		o.description = _('Used as the {{router}} variable in notification templates.');
		o = s.taboption('service', form.Value, 'queue_limit', _('Maximum queued deliveries'));
		o.default = '64';
		o.datatype = 'range(1,512)';
		o = s.taboption('service', form.Value, 'request_timeout', _('Provider timeout (seconds)'));
		o.default = '12';
		o.datatype = 'range(3,60)';
		o = s.taboption('service', form.Value, 'retry_limit', _('Maximum delivery attempts'));
		o.default = '3';
		o.datatype = 'range(1,10)';

		o = s.taboption('network', form.Value, 'wan_interfaces', _('WAN network interfaces'));
		o.default = 'wan wan6';
		o.description = _('Space-separated netifd interface names, for example: wan wan6.');
		o = s.taboption('network', form.Value, 'device_interface', _('LAN discovery device'));
		o.default = 'br-lan';
		o = s.taboption('network', form.Flag, 'discover_devices', _('Detect unknown LAN devices'));
		o.default = '1';
		o.description = _('Observes the existing neighbor table; it does not actively scan the LAN.');
		o = s.taboption('network', form.Value, 'monitor_interval', _('System scan interval (seconds)'));
		o.default = '30';
		o.datatype = 'range(10,600)';
		o = s.taboption('network', form.Value, 'known_probe_interval', _('Known device probe interval (seconds)'));
		o.default = '60';
		o.datatype = 'range(15,3600)';
		o = s.taboption('network', form.Flag, 'public_ip_enabled', _('Check public IPv4/IPv6'));
		o.default = '1';
		o.description = _('Uses external IP lookup services. Disable this to stop those external requests.');
		o = s.taboption('network', form.Value, 'public_ip_interval', _('Public IP check interval (seconds)'));
		o.default = '900';
		o.datatype = 'range(60,86400)';
		o.depends('public_ip_enabled', '1');
		o = s.taboption('network', form.Value, 'summary_interval', _('Status summary interval (seconds)'));
		o.default = '86400';
		o.datatype = 'range(300,604800)';
		o.description = _('The summary is delivered only when its event rule is enabled.');

		o = s.taboption('security', form.Value, 'auth_failures', _('Failed login threshold'));
		o.default = '5';
		o.datatype = 'range(2,100)';
		o = s.taboption('security', form.Value, 'auth_window', _('Failed login time window (seconds)'));
		o.default = '600';
		o.datatype = 'range(30,86400)';
		o.description = _('Counts recent failed SSH and LuCI login attempts. Enable the corresponding event rules to receive alerts.');

		o = s.taboption('health', form.Value, 'cpu_temperature', _('CPU temperature warning (°C)'));
		o.default = '80';
		o.datatype = 'range(1,150)';
		o = s.taboption('health', form.Value, 'load_threshold', _('Load warning threshold'));
		o.default = '4';
		o.datatype = 'range(1,128)';
		o = s.taboption('health', form.Value, 'memory_available_mb', _('Minimum available memory (MiB)'));
		o.default = '32';
		o.datatype = 'range(1,32768)';
		o = s.taboption('health', form.Value, 'storage_available_mb', _('Minimum free storage (MiB)'));
		o.default = '32';
		o.datatype = 'range(1,65536)';
		o = s.taboption('health', form.Value, 'storage_mount', _('Storage mountpoint'));
		o.default = '/';
		o.description = _('Filesystem checked for low-space alerts.');

		o = s.taboption('receiver', form.Flag, 'receiver_enabled', _('Enable HTTP message receiver'));
		o.default = '0';
		o.description = _('Off by default. The endpoint is /cgi-bin/catos-notify and uses the existing uhttpd server. No firewall rules are added.');
		o = s.taboption('receiver', form.ListValue, 'receiver_scope', _('Allowed source'));
		o.value('lan', _('LAN only'));
		o.value('external', _('External access (HTTPS required)'));
		o.default = 'lan';
		o = s.taboption('receiver', form.Flag, 'receiver_auth', _('Require authorization'));
		o.default = '1';
		o.description = _('Only optional for LAN access. External access always requires a token, even if this switch is off.');
		o = s.taboption('receiver', form.Value, 'receiver_token', _('Receiver token'));
		o.password = true;
		o.description = _('Use this secret in the X-CatOS-Token request header. Store it securely.');
		o = s.taboption('receiver', form.Button, '_generate_token', _('Generate new token'));
		o.inputstyle = 'action';
		o.onclick = function() {
			return generateToken().then(function(result) {
				var ok = result && (result.ok === true || result.ok === 1);
				ui.addNotification(null, E('p', {}, ok
					? _('Token generated. Reload this page to display the updated token.')
					: _('Token generation failed: ') + (result && result.message || _('Unknown error'))),
					ok ? 'info' : 'danger');
			}).catch(function(err) {
				ui.addNotification(null, E('p', {}, _('Request failed: ') + err.message), 'danger');
			});
		};
		o = s.taboption('receiver', form.Value, 'receiver_lan_interfaces', _('Allowed LAN devices'));
		o.placeholder = 'br-lan';
		o.description = _('Space-separated network device names. Empty uses the LAN discovery device.');
		o = s.taboption('receiver', form.Value, 'receiver_rate_limit', _('Requests per minute per IP'));
		o.default = '30';
		o.datatype = 'range(1,120)';

		return m.render();
	}
});
