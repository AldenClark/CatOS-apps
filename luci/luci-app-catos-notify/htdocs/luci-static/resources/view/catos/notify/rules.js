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

var commonVariables = [
	[ 'router', _('Router name') ], [ 'time', _('Notification time') ],
	[ 'event', _('Event ID') ], [ 'source', _('Publisher name') ],
	[ 'severity', _('Event severity') ], [ 'body', _('Original event details') ]
];
var eventVariables = {
	'wan.down': [ [ 'interface', _('Disconnected network interface') ] ],
	'wan.up': [ [ 'interface', _('Restored network interface') ] ],
	'wan.ipv4.changed': [ [ 'interface', _('Network interface') ], [ 'old', _('Previous IPv4 addresses (CIDR)') ], [ 'new', _('Current IPv4 addresses (CIDR)') ] ],
	'wan.ipv6.changed': [ [ 'interface', _('Network interface') ], [ 'old', _('Previous IPv6 addresses (CIDR)') ], [ 'new', _('Current IPv6 addresses (CIDR)') ] ],
	'wan.prefix.changed': [ [ 'interface', _('Network interface') ], [ 'old', _('Previous delegated prefixes (CIDR)') ], [ 'new', _('Current delegated prefixes (CIDR)') ] ],
	'public.ipv4.changed': [ [ 'old', _('Previous public IPv4 address') ], [ 'new', _('Current public IPv4 address') ] ],
	'public.ipv6.changed': [ [ 'old', _('Previous public IPv6 address') ], [ 'new', _('Current public IPv6 address') ] ],
	'wan.primary.changed': [ [ 'old', _('Previous default-route device') ], [ 'new', _('Current default-route device') ] ],
	'device.unknown.online': [ [ 'device', _('Detected device MAC') ], [ 'interface', _('Discovery bridge') ] ],
	'device.known.online': [ [ 'device', _('Configured device MAC (if set)') ], [ 'device_name', _('Configured device name') ], [ 'ip', _('Probe IP address') ] ],
	'device.known.offline': [ [ 'device', _('Configured device MAC (if set)') ], [ 'device_name', _('Configured device name') ], [ 'ip', _('Probe IP address') ] ],
	'auth.ssh.failed': [ [ 'count', _('Failed login count') ], [ 'window', _('Counting window (seconds)') ], [ 'origin', _('Last source IP (if available)') ] ],
	'auth.luci.failed': [ [ 'count', _('Failed login count') ], [ 'window', _('Counting window (seconds)') ], [ 'origin', _('Last source IP (if available)') ] ],
	'health.cpu_temp.high': [ [ 'value', _('CPU temperature (°C)') ], [ 'threshold', _('Temperature threshold (°C)') ] ],
	'health.load.high': [ [ 'value', _('One-minute load average') ], [ 'threshold', _('Load threshold') ] ],
	'health.memory.high': [ [ 'value', _('Available memory (MiB)') ], [ 'threshold', _('Memory threshold (MiB)') ] ],
	'health.storage.low': [ [ 'value', _('Available storage (MiB)') ], [ 'threshold', _('Storage threshold (MiB)') ], [ 'mount', _('Storage mount point') ] ],
	'system.boot': [], 'system.reboot': [],
	'system.summary': [ [ 'uptime', _('Uptime (seconds)') ], [ 'load', _('Load averages (1 / 5 / 15 minutes)') ], [ 'memory', _('Available memory (MiB)') ], [ 'storage', _('Available storage (MiB)') ], [ 'addresses', _('WAN address summary') ] ]
};

function templateVariables(event) {
	return commonVariables.concat(eventVariables[event] || []);
}

function variableHelp(option, sectionId) {
	var help = E('div', { 'class': 'catos-notify-variables' });
	var eventOption = option.section.children.filter(function(o) { return o.option === 'event'; })[0];
	function refresh(value) {
		var event = value == null ? (eventOption.formvalue(sectionId) || eventOption.cfgvalue(sectionId) || '') : value;
		help.replaceChildren(E('p', {}, _('Click a variable to insert it at the cursor in this template.')));
		templateVariables(event).forEach(function(item) {
			var token = '{{' + item[0] + '}}';
			help.appendChild(E('button', {
				type: 'button', 'class': 'catos-notify-variable',
				mousedown: function(ev) { ev.preventDefault(); },
				click: function() {
					var widget = document.getElementById(option.cbid(sectionId));
					var input = widget && widget.querySelector('input, textarea');
					if (!input || input.disabled || input.readOnly) return;
					var start = input.selectionStart == null ? input.value.length : input.selectionStart;
					var end = input.selectionEnd == null ? start : input.selectionEnd;
					input.setRangeText(token, start, end, 'end');
					input.focus();
					input.dispatchEvent(new Event('input', { bubbles: true }));
					input.dispatchEvent(new Event('change', { bubbles: true }));
				}
			}, [ E('code', {}, token), E('span', {}, item[1]) ]));
		});
		if (!Object.prototype.hasOwnProperty.call(eventVariables, event))
			help.appendChild(E('p', {}, _('Custom event variables depend on its publisher. Add flat data keys as {{key}}; only common variables are listed here.')));
	}
	help.updateVariables = refresh;
	refresh();
	return help;
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
		s.nodescriptions = true;
		s.anonymous = true;
		s.description = _('Choose channels and/or groups under Delivery. If a channel is selected both directly and through a group, it receives one message.');

		var o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.width = '5rem';
		o.default = '1';
		o.rmempty = false;
		o = s.option(form.Value, 'event', _('Event'));
		o.width = '22%';
		events.forEach(function(item) { o.value(item[0], item[1]); });
		o.rmempty = false;
		o.onchange = function(ev, sectionId, value) {
			var map = ev.target.closest('.cbi-map');
			if (map) map.querySelectorAll('.catos-notify-variables').forEach(function(help) { help.updateVariables(value); });
		};
		o.description = _('Select a built-in event or type an exact custom event ID, such as ddns.updated.');
		// GridSection normally renders the stored ID (e.g. wan.down).
		// Show its translated label in the table while keeping the UCI value intact.
		o.textvalue = function(sectionId) {
			var id = this.cfgvalue(sectionId);
			return '%h'.format(eventLabels[id] || id || '');
		};
		o = s.option(form.MultiValue, 'targets', _('Delivery'));
		o.width = '24%';
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
		o.width = '28%';
		o.rmempty = false;
		o.description = _('This title template belongs only to this event rule.');
		var renderTitle = o.renderWidget;
		o.renderWidget = function(sectionId) {
			return Promise.resolve(renderTitle.apply(this, arguments)).then(function(node) {
				return E('div', {}, [ node, variableHelp(this, sectionId) ]);
			}.bind(this));
		};
		o.textvalue = function(sectionId) {
			var title = this.cfgvalue(sectionId) || '';
			return '%h'.format(title.length > 55 ? title.slice(0, 55) + '…' : title);
		};

		o = s.option(form.TextValue, 'body', _('Message body template'));
		o.modalonly = true;
		o.rows = 5;
		o.rmempty = false;
		o.description = _('Use {{body}} for the original event details.');
		var renderBody = o.renderWidget;
		o.renderWidget = function(sectionId) {
			return Promise.resolve(renderBody.apply(this, arguments)).then(function(node) {
				return E('div', {}, [ node, variableHelp(this, sectionId) ]);
			}.bind(this));
		};

		o = s.option(form.Value, 'cooldown', _('Cooldown (seconds)'));
		o.width = '8rem';
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

		return m.render().then(function(node) {
			node.classList.add('catos-notify-page', 'catos-notify-rules');
			// Argon overrides native column widths with width:auto !important.
			node.querySelectorAll('thead th').forEach(function(cell) {
				if (cell.style.width) cell.style.setProperty('width', cell.style.width, 'important');
			});
			node.prepend(E('link', { rel: 'stylesheet', href: L.resource('view/catos/notify/overview.css') }));
			return node;
		});
	}
});
