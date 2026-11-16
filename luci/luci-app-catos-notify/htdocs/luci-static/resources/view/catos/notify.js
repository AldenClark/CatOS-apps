'use strict';
'require view';
'require rpc';
'require ui';

var getStatus = rpc.declare({
	object: 'catos.notify',
	method: 'status',
	expect: { '': {} }
});

var sendMessage = rpc.declare({
	object: 'catos.notify',
	method: 'send',
	params: [ 'title', 'body', 'group' ],
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

function historyTable(records) {
	if (!Array.isArray(records) || !records.length)
		return E('p', {}, _('No delivery records yet.'));

	var rows = records.slice().reverse().map(function(record) {
		var fields = String(record).split('|');
		var date = Number(fields[0]);
		var results = {
			'success': _('Delivered'),
			'failed': _('Failed'),
			'queue_full': _('Queue full')
		};
		var events = {
			'queued': _('Queued delivery'),
			'test': _('Test message')
		};
		return E('tr', {}, [
			E('td', {}, Number.isFinite(date) && date > 0
				? new Date(date * 1000).toLocaleString() : '-'),
			E('td', {}, fields[1] || '-'),
			E('td', {}, results[fields[2]] || fields[2] || '-'),
			E('td', {}, events[fields[3]] || fields[3] || '-')
		]);
	});

	return E('div', { 'style': 'overflow-x: auto' },
		E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Time')),
				E('th', { 'class': 'th' }, _('Channel')),
				E('th', { 'class': 'th' }, _('Result')),
				E('th', { 'class': 'th' }, _('Event'))
			]),
		].concat(rows)));
}

return view.extend({
	load: function() {
		return getStatus().catch(function() { return null; });
	},

	render: function(status) {
		var title = messageField('title', _('Title'), 'input');
		var body = messageField('body', _('Message body'), 'textarea');
		var group = messageField('group', _('Delivery group'), 'input', 'default');
		group.input.value = 'default';

		return E('div', {}, [
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
				E('p', {}, _('Send a one-off notification to every enabled channel in the chosen delivery group.')),
				E('div', { 'class': 'catos-notify-compose' }, [
					title.row,
					body.row,
					group.row,
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
								ev.currentTarget.disabled = true;
								return sendMessage(title.input.value.trim(), body.input.value, group.input.value.trim() || 'default')
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
