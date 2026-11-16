'use strict';
'require view';
'require form';
'require uci';

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

var eventLabels = Object.create(null);
events.forEach(function(item) { eventLabels[item[0]] = item[1]; });

function templateVariables(event) {
	var common = '{{router}}, {{time}}, {{event}}, {{source}}, {{severity}}, {{body}}';
	if (/^(wan\.|public\.)/.test(event))
		return common + ', {{interface}}, {{old}}, {{new}}';
	if (/^device\./.test(event))
		return common + ', {{device}}, {{interface}}, {{old}}, {{new}}';
	return common + (event === 'system.summary' ? '' : ', {{interface}}, {{device}}, {{old}}, {{new}}');
}

return view.extend({
	load: function() {
		return uci.load('catos_notify');
	},

	render: function() {
		var destinations = Object.create(null);
		var channelOptions = uci.sections('catos_notify', 'channel').filter(function(section) {
			return /^[a-zA-Z0-9_-]+$/.test(section['.name']);
		});
		var groupOptions = uci.sections('catos_notify', 'group').filter(function(section) {
			return /^[a-zA-Z0-9_-]+$/.test(section['.name']);
		});
		groupOptions.forEach(function(group) {
			destinations['group:' + group['.name']] = _('Group: ') + (group.name || group['.name']);
		});
		channelOptions.forEach(function(channel) {
			destinations['channel:' + channel['.name']] = _('Channel: ') + (channel.name || channel['.name']);
		});

		var m = new form.Map('catos_notify', _('Event rules'),
			_('Each rule selects an event, its destinations and its own message template. No destination is selected automatically.'));
		var s = m.section(form.GridSection, 'rule', _('Notification rules'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Choose channels and/or groups under Delivery. If a channel is selected both directly and through a group, it receives one message.');

		var o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o.rmempty = false;
		o = s.option(form.Value, 'event', _('Event'));
		events.forEach(function(item) { o.value(item[0], item[1]); });
		o.rmempty = false;
		o.description = _('Select a built-in event or type an exact custom event ID, such as ddns.updated.');
		// GridSection normally renders the stored ID (e.g. wan.down).
		// Show its translated label in the table while keeping the UCI value intact.
		o.textvalue = function(sectionId) {
			var id = this.cfgvalue(sectionId);
			return '%h'.format(eventLabels[id] || id || '');
		};
		o = s.option(form.MultiValue, 'targets', _('Delivery'));
		o.rmempty = true;
		o.create = false;
		o.description = _('Select any number of delivery groups and individual channels. An empty selection means this rule does not deliver.');
		groupOptions.forEach(function(group) {
			var key = 'group:' + group['.name'];
			o.value(key, destinations[key]);
		});
		channelOptions.forEach(function(channel) {
			var key = 'channel:' + channel['.name'];
			o.value(key, destinations[key]);
		});
		o.textvalue = function(sectionId) {
			var selected = this.cfgvalue(sectionId);
			if (!Array.isArray(selected)) selected = selected ? [ selected ] : [];
			var value = selected.map(function(key) {
				return destinations[key] || _('Missing destination: ') + key;
			}).join(', ');
			return '%h'.format(value || _('Not configured'));
		};

		o = s.option(form.Value, 'title', _('Notification title'));
		o.rmempty = false;
		o.description = _('This title template belongs only to this event rule.');
		o.textvalue = function(sectionId) {
			var title = this.cfgvalue(sectionId) || '';
			return '%h'.format(title.length > 55 ? title.slice(0, 55) + '…' : title);
		};

		o = s.option(form.TextValue, 'body', _('Message body template'));
		o.modalonly = true;
		o.rows = 5;
		o.rmempty = false;
		o.description = _('Use {{body}} for the event details. Extra flat variables from the event data are also available.');

		o = s.option(form.DummyValue, '_variables', _('Available variables for this event'));
		o.modalonly = true;
		o.cfgvalue = function(sectionId) {
			return templateVariables(uci.get('catos_notify', sectionId, 'event') || '');
		};

		o = s.option(form.Value, 'cooldown', _('Cooldown (seconds)'));
		o.datatype = 'uinteger';
		o.default = '60';
		o.textvalue = function(sectionId) {
			return '%h'.format((this.cfgvalue(sectionId) || '60') + ' s');
		};
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
