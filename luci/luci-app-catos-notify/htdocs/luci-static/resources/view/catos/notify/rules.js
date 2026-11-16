'use strict';
'require view';
'require form';

var events = [
	[ 'wan.down', _('WAN · Disconnected') ],
	[ 'wan.up', _('WAN · Restored') ],
	[ 'wan.ipv4.changed', _('WAN · IPv4 changed') ],
	[ 'wan.ipv6.changed', _('WAN · IPv6 changed') ],
	[ 'wan.prefix.changed', _('WAN · Delegated IPv6 prefix changed') ],
	[ 'public.ipv4.changed', _('WAN · Public IPv4 changed') ],
	[ 'public.ipv6.changed', _('WAN · Public IPv6 changed') ],
	[ 'wan.primary.changed', _('WAN · Primary connection changed') ],
	[ 'device.unknown.online', _('Devices · Unknown device detected') ],
	[ 'device.known.online', _('Devices · Monitored device online') ],
	[ 'device.known.offline', _('Devices · Monitored device offline') ],
	[ 'auth.ssh.failed', _('Security · Repeated SSH login failures') ],
	[ 'auth.luci.failed', _('Security · Repeated LuCI login failures') ],
	[ 'system.boot', _('System · Startup complete') ],
	[ 'system.reboot', _('System · Reboot or shutdown initiated') ],
	[ 'health.cpu_temp.high', _('Health · High CPU temperature') ],
	[ 'health.load.high', _('Health · High system load') ],
	[ 'health.memory.high', _('Health · Low available memory') ],
	[ 'health.storage.low', _('Health · Low free storage') ],
	[ 'system.summary', _('System · Periodic status summary') ]
];

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Event rules'),
			_('Choose what triggers a notification and where it is delivered. A disabled rule suppresses its event.'));
		var s = m.section(form.GridSection, 'rule', _('Notification rules'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('The event ID is the trigger. The delivery group must match a configured channel group. Use the template ID to control the message format.');

		var o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o = s.option(form.Value, 'event', _('Event ID'));
		events.forEach(function(item) { o.value(item[0], item[1]); });
		o.rmempty = false;
		o.description = _('Select a built-in event or type an exact custom event ID, such as ddns.updated.');
		o = s.option(form.Value, 'group', _('Delivery group'));
		o.default = 'default';
		o = s.option(form.Value, 'template', _('Template ID'));
		o.default = 'default';
		o.modalonly = true;
		o.description = _('Select the section ID of a message template, usually default or summary.');
		o = s.option(form.Value, 'cooldown', _('Cooldown (seconds)'));
		o.datatype = 'uinteger';
		o.default = '60';
		o.modalonly = true;
		o.description = _('Minimum time between matching notifications. Set 0 to disable throttling.');
		o = s.option(form.Value, 'interface', _('Network interface filter'));
		o.modalonly = true;
		o.description = _('Optional. Match a specific netifd network interface.');
		o = s.option(form.Value, 'source', _('Event source filter'));
		o.modalonly = true;
		o.description = _('Optional. Match the exact source name supplied by an event publisher.');
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

		return m.render();
	}
});
