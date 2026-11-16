'use strict';
'require view';
'require form';
'require rpc';
'require ui';

var testChannel = rpc.declare({
	object: 'catos.notify',
	method: 'test',
	params: [ 'channel', 'title', 'body' ],
	expect: { '': {} }
});

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Notification channels'),
			_('Channels are delivery destinations. Create a channel for each provider account or device, then assign channels to delivery groups.'));
		var s = m.section(form.GridSection, 'channel', _('Configured channels'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Save & Apply before testing a new channel or changed credentials. Testing sends directly to the selected destination.');

		var o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';

		o = s.option(form.Value, 'name', _('Display name'));
		o.rmempty = false;
		o.placeholder = _('e.g. My phone');

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
		o.description = _('Rules and manual messages target a group, so multiple channels can receive the same event.');

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
		o.onclick = function(ev, sectionId) {
			return testChannel(sectionId, 'CatOS Notify test', 'This is a test notification.')
				.then(function(result) {
					var ok = result && (result.ok === true || result.ok === 1);
					ui.addNotification(null, E('p', {}, ok
						? _('Test notification delivered.')
						: _('Test failed: ') + (result && result.message || _('Unknown error'))),
						ok ? 'info' : 'danger');
				})
				.catch(function(err) {
					ui.addNotification(null, E('p', {}, _('Request failed: ') + err.message), 'danger');
				});
		};

		return m.render();
	}
});
