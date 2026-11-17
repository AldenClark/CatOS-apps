'use strict';
'require view';
'require form';
'require rpc';
'require ui';
'require uci';

var testChannel = rpc.declare({
	object: 'catos.notify',
	method: 'test',
	params: [ 'channel', 'title', 'body' ],
	expect: { '': {} }
});

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Notification channels'),
			_('Configure a delivery destination here. Delivery groups maintain their own channel membership.'));
		var s = m.section(form.GridSection, 'channel', _('Configured channels'));
		s.addremove = true;
		s.nodescriptions = true;
		s.anonymous = true;
		s.description = _('Each channel has a permanent internal ID so group references remain safe when other channels are removed. Save & Apply before testing.');
		// LuCI normally creates anonymous @channel[index] sections. Such indices
		// shift when a different channel is removed, potentially misrouting
		// notifications. Create named UCI sections without asking for IDs.
		var originalAdd = s.handleAdd;
		s.handleAdd = function(ev) {
			var id;
			do {
				id = 'channel_' + Date.now().toString(36) + '_' +
					Math.random().toString(36).slice(2, 10);
			} while (this.map.data.get('catos_notify', id) != null);
			return originalAdd.call(this, ev, id);
		};

		var o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.width = '5rem';
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'name', _('Display name'));
		o.width = '45%';
		o.rmempty = false;
		o.placeholder = _('e.g. My phone');

		o = s.option(form.ListValue, 'type', _('Provider'));
		o.width = '25%';
		[
			[ 'bark', 'Bark' ], [ 'pushgo', 'PushGo' ], [ 'ntfy', 'ntfy' ],
			[ 'feishu', _('Feishu') ], [ 'dingtalk', _('DingTalk') ],
			[ 'wecom', _('WeCom') ], [ 'telegram', 'Telegram' ],
			[ 'webhook', _('Generic Webhook') ]
		].forEach(function(type) { o.value(type[0], type[1]); });
		o.rmempty = false;

		o = s.option(form.Value, 'url', _('Server / webhook URL'));
		o.modalonly = true;
		o.description = _('Optional for providers with a built-in endpoint. Use HTTPS for public services.');

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
		[ 'telegram', 'pushgo', 'ntfy', 'webhook' ].forEach(function(provider) {
			o.depends('type', provider);
		});

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

		o = s.option(form.Button, '_test', _('Send test'));
		o.inputstyle = 'apply';
		// The backend uses saved credentials. Compare every editor value too:
		// uci.changes() alone cannot see edits still inside an open modal.
		o.modalonly = true;
		o.inputtitle = _('Send test');
		o.onclick = function(ev, sectionId) {
			var button = ev.currentTarget;
			var dirty = this.section.children.some(function(option) {
				if (option.option === '_test' || !option.isActive(sectionId)) return false;
				var value = option.formvalue(sectionId);
				var saved = option.cfgvalue(sectionId);
				if (saved == null) saved = option.default;
				return value != null && String(value) !== String(saved || '');
			});
			button.disabled = true;
			return uci.changes().then(function(changes) {
				if (dirty || (changes.catos_notify && changes.catos_notify.length)) {
					ui.addNotification(null, E('p', {},
						_('Save & Apply before testing new channels or changed credentials.')),
						'warning');
					return;
				}
				return testChannel(sectionId, 'CatOS Notify test', 'This is a test notification.');
			})
				.then(function(result) {
					if (!result) return;
					var ok = result && (result.ok === true || result.ok === 1);
					var failures = {
						channel_unknown: _('Channel not found. Save & Apply before testing.'),
						delivery_failed: _('Delivery failed. Check the provider URL, credentials and network connectivity.')
					};
					var message = result && result.message;
					ui.addNotification(null, E('p', {}, ok
						? _('Test notification delivered.')
						: _('Test failed: ') + (failures[message] || message || _('Unknown error'))),
						ok ? 'info' : 'danger');
				})
				.catch(function(err) {
					ui.addNotification(null, E('p', {}, _('Request failed: ') + err.message), 'danger');
				}).finally(function() { button.disabled = false; });
		};

		return m.render().then(function(node) {
			node.classList.add('catos-notify-page', 'catos-notify-channels');
			// Argon overrides native column widths with width:auto !important.
			node.querySelectorAll('thead th').forEach(function(cell) {
				if (cell.style.width) cell.style.setProperty('width', cell.style.width, 'important');
			});
			node.prepend(E('link', { rel: 'stylesheet', href: L.resource('view/catos/notify/overview.css') }));
			return node;
		});
	}
});
