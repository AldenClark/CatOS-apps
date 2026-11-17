'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m = new form.Map('catos_notify', _('Monitored devices'),
			_('Track important LAN devices and receive online/offline events when their reachability changes.'));
		var s = m.section(form.GridSection, 'device', _('Known LAN devices'));
		s.addremove = true;
		s.nodescriptions = true;
		s.anonymous = true;
		s.description = _('Enter an IP address that responds to probes. Repeated failed checks are required before a device is marked offline.');

		var o = s.option(form.Flag, 'monitor', _('Monitor'));
		o.width = '5rem';
		o.default = '1';
		o.rmempty = false;
		o = s.option(form.Value, 'name', _('Device name'));
		o.width = '28%';
		o.rmempty = false;
		o = s.option(form.Value, 'mac', _('MAC address'));
		o.width = '12rem';
		o.datatype = 'macaddr';
		o = s.option(form.Value, 'ip', _('Probe IP address'));
		o.width = '14rem';
		o.datatype = 'ipaddr';
		o.rmempty = false;

		return m.render().then(function(node) {
			node.classList.add('catos-notify-page', 'catos-notify-devices');
			// Argon overrides native column widths with width:auto !important.
			node.querySelectorAll('thead th').forEach(function(cell) {
				if (cell.style.width) cell.style.setProperty('width', cell.style.width, 'important');
			});
			node.prepend(E('link', { rel: 'stylesheet', href: L.resource('view/catos/notify/overview.css') }));
			return node;
		});
	}
});
