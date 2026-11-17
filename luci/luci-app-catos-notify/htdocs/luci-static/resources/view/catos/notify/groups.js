'use strict';
'require view';
'require form';
'require uci';

function listChannels() {
	return uci.sections('catos_notify', 'channel').filter(function(section) {
		// Only permanent named sections can safely be referenced by a group.
		return /^[a-zA-Z0-9_-]+$/.test(section['.name']);
	});
}

return view.extend({
	load: function() {
		return uci.load('catos_notify');
	},

	render: function() {
		var channels = listChannels();
		var names = Object.create(null);
		channels.forEach(function(channel) {
			names[channel['.name']] = channel.name || channel['.name'];
		});

		var m = new form.Map('catos_notify', _('Delivery groups'),
			_('A delivery group contains one or more channels. Manage membership here; channels themselves do not belong to any default group.'));
		var s = m.section(form.GridSection, 'group', _('Configured delivery groups'));
		s.addremove = true;
		s.nodescriptions = true;
		s.anonymous = true;
		s.description = _('A channel may be included in multiple groups. A group with no channels cannot deliver messages.');

		var originalAdd = s.handleAdd;
		s.handleAdd = function(ev) {
			var id;
			do {
				id = 'group_' + Date.now().toString(36) + '_' +
					Math.random().toString(36).slice(2, 10);
			} while (this.map.data.get('catos_notify', id) != null);
			return originalAdd.call(this, ev, id);
		};

		var o = s.option(form.Value, 'name', _('Group name'));
		o.width = '30%';
		o.rmempty = false;
		o.placeholder = _('e.g. Administrator devices');

		o = s.option(form.MultiValue, 'channels', _('Member channels'));
		o.width = '55%';
		o.rmempty = true;
		o.create = false;
		channels.forEach(function(channel) {
			o.value(channel['.name'], names[channel['.name']]);
		});
		o.textvalue = function(sectionId) {
			var members = this.cfgvalue(sectionId);
			if (!Array.isArray(members)) members = members ? [ members ] : [];
			var value = members.map(function(id) {
				return names[id] || _('Missing channel: ') + id;
			}).join(', ');
			return '%h'.format(value || _('No member channels'));
		};

		return m.render().then(function(node) {
			node.classList.add('catos-notify-page', 'catos-notify-groups');
			// Argon overrides native column widths with width:auto !important.
			node.querySelectorAll('thead th').forEach(function(cell) {
				if (cell.style.width) cell.style.setProperty('width', cell.style.width, 'important');
			});
			node.prepend(E('link', { rel: 'stylesheet', href: L.resource('view/catos/notify/overview.css') }));
			return node;
		});
	}
});
