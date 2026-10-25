import {withAppShare} from '../../lib/share.js';
import {protectedPage} from '../../lib/auth-page.js';
import {comparison} from '../../lib/model.js';
import {service,attempt,notify} from '../../lib/ui.js';
Page(withAppShare(protectedPage({data:{houses:[],selected:[],comparing:false,differences:false,rows:[]},onShow(){const houses=service().store.get().houses.filter(h=>!h.archived).map(h=>({...h,cover:h.media.find(m=>m.type==='image')?.path||'',rent:h.answers.f1_6?.value||'—',area:h.answers.f1_3?.value||'—'})),selected=this.data.selected.filter(id=>houses.some(h=>h.id===id));this.setData({houses,selected,comparing:false});},
 toggle(e){const id=e.currentTarget.dataset.id,selected=this.data.selected;if(!selected.includes(id)&&selected.length===3){notify('最多对比 3 套房源');return;}this.setData({selected:selected.includes(id)?selected.filter(x=>x!==id):[...selected,id]});},
 compare(){attempt(()=>{const houses=this.data.selected.map(id=>service().store.house(id));this.setData({rows:comparison(houses,this.data.differences).map(r=>({...r,different:new Set(r.values).size>1})),compared:houses,comparing:true});});},
 differences(e){this.setData({differences:e.detail.value});this.compare();},back(){this.setData({comparing:false});}
})));
