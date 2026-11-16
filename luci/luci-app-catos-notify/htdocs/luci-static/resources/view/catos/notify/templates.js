'use strict';
'require view';
'require form';
'require rpc';
'require ui';

var sendTemplate = rpc.declare({
	object: 'catos.notify',
	method: 'send',
	params: [ 'title', 'body', 'group', 'template', 'data' ],
	expect: { '': {} }
});

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Message templates'),
			_('Templates define the title and body of notifications. Event rules refer to a template by its section ID.'));
		var s = m.section(form.GridSection, 'template', _('Available templates'));
		s.addremove = true;
		s.anonymous = true;
		s.description = _('Variables: {{router}}, {{event}}, {{time}}, {{body}}, {{old}}, {{new}}, {{interface}}. Custom event data fields can also be used.');

		var o = s.option(form.Value, 'name', _('Display name'));
		o.rmempty = false;
		o = s.option(form.Value, 'title', _('Notification title'));
		o.rmempty = false;
		o = s.option(form.TextValue, 'body', _('Message body'));
		o.modalonly = true;
		o.rows = 5;
		o.rmempty = false;
		o.description = _('Use {{body}} for the event details and {{router}} for the configured router name.');
		o = s.option(form.Button, '_test', _('Queue test message'));
		o.inputstyle = 'apply';
		o.onclick = function(ev, sectionId) {
			return sendTemplate('', '', 'default', sectionId, {
				interface: 'wan', device: 'aa:bb:cc:dd:ee:ff',
				old: '192.0.2.10', new: '192.0.2.11'
			}).then(function(result) {
				var ok = result && (result.ok === true || result.ok === 1);
				ui.addNotification(null, E('p', {}, ok
					? _('Test template queued for the default delivery group.')
					: _('Could not queue template: ') + (result && result.message || _('Unknown error'))),
					ok ? 'info' : 'danger');
			}).catch(function(err) {
				ui.addNotification(null, E('p', {}, _('Request failed: ') + err.message), 'danger');
			});
		};

		return m.render();
	}
});
