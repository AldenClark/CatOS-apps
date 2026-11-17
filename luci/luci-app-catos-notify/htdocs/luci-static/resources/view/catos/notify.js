'use strict';
'require view';
'require rpc';
'require ui';
'require uci';

var getStatus = rpc.declare({
	object: 'catos.notify',
	method: 'status',
	expect: { '': {} }
});

var sendMessage = rpc.declare({
	object: 'catos.notify',
	method: 'send',
	params: [ 'title', 'body', 'targets' ],
	expect: { '': {} }
});

function resultNotification(result) {
	var ok = result && (result.ok === true || result.ok === 1);
	ui.addNotification(null, E('p', {}, ok
		? _('Message added to the delivery queue.')
		: _('Could not queue message: ') + (result && result.message || _('Unknown error'))),
		ok ? 'info' : 'danger');
}

function statusLine(label, value) {
	return E('div', { 'class': 'cbi-value' }, [
		E('label', { 'class': 'cbi-value-title' }, label),
		E('div', { 'class': 'cbi-value-field' }, value)
	]);
}

function messageField(id, label, type, placeholder) {
	var multiline = type === 'textarea';
	var attributes = {
		'id': 'catos-notify-' + id,
		'class': multiline ? 'cbi-input-textarea' : 'cbi-input-text',
		'placeholder': placeholder || label
	};
	if (multiline) attributes.rows = 4;
	var input = E(multiline ? 'textarea' : 'input', attributes);
	return {
		input: input,
		row: E('div', { 'class': 'catos-notify-compose-row' }, [
			E('label', { 'class': 'catos-notify-compose-label', 'for': 'catos-notify-' + id }, label),
			E('div', { 'class': 'catos-notify-compose-control' }, input)
		])
	};
}

function deliveryChoices() {
	var choices = [];
	uci.sections('catos_notify', 'group').forEach(function(group) {
		if (/^[a-zA-Z0-9_-]+$/.test(group['.name']))
			choices.push([ 'group:' + group['.name'], _('Group: ') + (group.name || group['.name']) ]);
	});
	uci.sections('catos_notify', 'channel').forEach(function(channel) {
		if (/^[a-zA-Z0-9_-]+$/.test(channel['.name']))
			choices.push([ 'channel:' + channel['.name'], _('Channel: ') + (channel.name || channel['.name']) ]);
	});
	return choices;
}

function targetsField() {
	var checkboxes = deliveryChoices().map(function(choice) {
		var checkbox = E('input', { 'type': 'checkbox', 'value': choice[0] });
		return {
			input: checkbox,
			row: E('label', { 'class': 'catos-notify-target-item' }, [ checkbox, E('span', {}, [ choice[1] ]) ])
		};
	});
	return {
		checkboxes: checkboxes,
		row: E('div', { 'class': 'catos-notify-compose-row' }, [
			E('span', { 'class': 'catos-notify-compose-label' }, _('Delivery')),
			E('div', { 'class': 'catos-notify-compose-control' }, [
				checkboxes.length
					? E('div', { 'class': 'catos-notify-targets' }, checkboxes.map(function(entry) { return entry.row; }))
					: E('p', {}, _('No channels or groups configured. Add a channel first.')),
				E('p', { 'class': 'description' }, _('Select one or more destinations. Channels included through multiple selections receive only one copy.'))
			])
		])
	};
}

function historyTable(records) {
	if (!Array.isArray(records) || !records.length)
		return E('p', {}, _('No delivery records yet.'));

	var results = { success: _('Delivered'), failed: _('Failed; retry pending'),
		exhausted: _('Retry limit reached'), queue_full: _('Queue full') };
	var rows = records.slice().reverse().map(function(record) {
		// Older installed cores return delimiter-separated metadata without content.
		if (typeof record === 'string') {
			var fields = record.split('|');
			record = { time: fields[0], result: fields[2], event: fields[3] };
		}
		var date = Number(record.time);
		var time = Number.isFinite(date) && date > 0 ? new Date(date * 1000).toLocaleString() : '-';
		var result = results[record.result] || record.result || '-';
		var preview = record.title || _('Content unavailable');
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td' }, [ time ]),
			E('td', { 'class': 'td' }, [ preview ]),
			E('td', { 'class': 'td' }, [ result ]),
			E('td', { 'class': 'td' }, E('button', {
				type: 'button', 'class': 'btn cbi-button',
				click: function() {
					ui.showModal(_('Delivery details'), [
						E('p', {}, [ time + ' · ' + result ]),
						E('p', {}, [ _('Event') + ': ' + (record.event || '-') ]),
						E('h5', {}, _('Title')),
						E('div', { 'class': 'catos-notify-content' }, [ record.title || _('Content unavailable') ]),
						E('h5', {}, _('Message body')),
						E('div', { 'class': 'catos-notify-content' }, [ record.body == null ? _('Content unavailable') : record.body ]),
						E('div', { 'class': 'right' }, E('button', {
							type: 'button', 'class': 'btn cbi-button', click: ui.hideModal
						}, _('Close')))
					]);
				}
			}, _('View content')))
		]);
	});
	return E('div', { 'class': 'catos-notify-table-scroll' },
		E('table', { 'class': 'table catos-notify-history' }, [
			E('thead', {}, E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Time')),
				E('th', { 'class': 'th' }, _('Title')),
				E('th', { 'class': 'th' }, _('Result')),
				E('th', { 'class': 'th' }, _('Details'))
			])), E('tbody', {}, rows)
		]));
}

return view.extend({
	load: function() {
		return uci.load('catos_notify').then(function() {
			return getStatus().catch(function() { return null; });
		});
	},

	render: function(status) {
		var title = messageField('title', _('Title'), 'input');
		var body = messageField('body', _('Message body'), 'textarea');
		var targets = targetsField();

		return E('div', { 'class': 'catos-notify-page' }, [
			E('link', { 'rel': 'stylesheet', 'href': L.resource('view/catos/notify/overview.css') }),
			E('h2', {}, _('CatOS Notify')),
			E('p', {}, _('Configure delivery channels first, then select which events should send notifications.')),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Service overview')),
				statusLine(_('Service state'), status === null ? _('Unavailable')
					: status.enabled ? _('Enabled') : _('Disabled')),
				statusLine(_('Pending deliveries'), status === null ? '-' : String(status.queued || 0)),
				E('p', {}, _('Configure service startup, monitoring, and the HTTP receiver on the Settings page.'))
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Send a message')),
				E('p', {}, _('Send a one-off notification to explicitly selected channels and delivery groups.')),
				E('div', { 'class': 'catos-notify-compose' }, [
					title.row,
					body.row,
					targets.row,
					E('div', { 'class': 'catos-notify-compose-row catos-notify-compose-actions' }, [
						E('div', { 'class': 'catos-notify-compose-label', 'aria-hidden': 'true' }),
						E('div', { 'class': 'catos-notify-compose-control' }, E('button', {
							'class': 'btn cbi-button cbi-button-action',
							'type': 'button',
							'click': function(ev) {
								if (!title.input.value.trim() || !body.input.value.trim()) {
									ui.addNotification(null, E('p', {}, _('Enter a title and message body.')), 'warning');
									return;
								}
								var selected = targets.checkboxes.filter(function(entry) {
									return entry.input.checked;
								}).map(function(entry) { return entry.input.value; });
								if (!selected.length) {
									ui.addNotification(null, E('p', {}, _('Select at least one delivery destination.')), 'warning');
									return;
								}
								ev.currentTarget.disabled = true;
								return sendMessage(title.input.value.trim(), body.input.value, selected)
									.then(resultNotification)
									.catch(function(err) {
										ui.addNotification(null, E('p', {}, _('Request failed: ') + err.message), 'danger');
									})
									.finally(function() { ev.currentTarget.disabled = false; });
							}
						}, _('Queue message')))
					])
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Recent delivery history')),
				E('p', {}, _('The latest delivery attempts are stored in memory and cleared when the router restarts.')),
				status === null ? E('p', {}, _('Status is temporarily unavailable.'))
					: historyTable(status.history)
			])
		]);
	}
});
