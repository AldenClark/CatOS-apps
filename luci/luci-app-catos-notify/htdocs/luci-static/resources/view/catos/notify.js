'use strict';
'require view';

return view.extend({
	render: function() {
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('CatOS Notify')),
			E('p', {}, _('The notification service is under development. Configuration and notification delivery will be available in a future release.'))
		]);
	},
	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
