import {protectedPage} from '../../lib/auth-page.js';
import {service,notify} from '../../lib/ui.js';
import {modeLabels,selectedMode} from '../../lib/templates.js';
Page(protectedPage({
 data:{modes:Object.keys(modeLabels).map(id=>({id,label:modeLabels[id]})),selected:'detailed'},
 onLoad(){this.setData({selected:selectedMode(service().store.get().settings)});},
 choose(e){const mode=e.currentTarget.dataset.mode;if(Object.keys(modeLabels).includes(mode))this.setData({selected:mode});},
 open(e){const mode=e.currentTarget.dataset.mode;if(Object.keys(modeLabels).includes(mode))wx.navigateTo({url:'/pages/template-edit/index?mode='+mode});},
 confirm(){try{service().store.change(s=>s.settings.selectedTemplate=this.data.selected,true);wx.navigateBack();}catch(error){notify(error);}}
}));
