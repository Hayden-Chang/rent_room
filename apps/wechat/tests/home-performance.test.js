import {it,expect} from 'vitest';
import {detailFixture} from './helpers/detail-performance.js';
it('sends only card fields for thirty houses and preserves navigation and stored detail',()=>{
 const s=detailFixture(30),before=JSON.stringify(s.store.get());s.patches.length=0;const home=s.home();
 const cards=s.patches.filter(p=>'houses' in p);expect(cards.length).toBeGreaterThan(0);
 expect(Buffer.byteLength(JSON.stringify(cards.at(-1)))).toBeLessThan(20000);
 expect(home.data.houses).toHaveLength(30);
 expect(home.data.houses[0]).toMatchObject({id:s.id,name:'点选性能',rent:'4800',cover:'/user/photo.jpg',stats:{done:1}});
 expect(home.data.houses[0]).not.toHaveProperty('templateTopics');expect(home.data.houses[0]).not.toHaveProperty('answers');
 home.open({currentTarget:{dataset:{id:s.id}}});expect(s.io.routes.at(-1)).toBe('/pages/detail/index?id='+s.id);
 expect(JSON.stringify(s.store.get())).toBe(before);
 home.onUnload();
});
