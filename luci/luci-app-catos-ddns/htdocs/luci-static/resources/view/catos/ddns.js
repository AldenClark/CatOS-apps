'use strict';
'require view';

return view.extend({
	render: function() {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('CatOS DDNS')),
			E('p', {}, _('The dynamic DNS service is under development. DNS provider configuration and record updates will be available in a future release.'))
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
