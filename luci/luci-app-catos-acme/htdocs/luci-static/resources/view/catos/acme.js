'use strict';
'require view';

return view.extend({
	render: function() {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('CatOS ACME')),
			E('p', {}, _('ACME certificate management is under development. Certificate issuance, renewal, and deployment will be available in a future release.'))
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
