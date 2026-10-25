import templateCategories from './template-categories.json' with {type:'json'};
import {indoorCategories,simpleCategory} from './checklist-categories.js';

export {templateCategories};
export const modeLabels={simple:'精简模式',detailed:'详细模式'};
export const selectedMode=settings=>settings?.selectedTemplate==='simple'?'simple':'detailed';
export function templateConfig(settings={},mode='detailed') {
  const saved=settings.templates?.[mode]||{};
  const category=mode==='simple'?simpleCategory:id=>id;
  const categories=[...new Set(templateCategories.map(category))],disabled=saved.disabled||[];
  return {order:[...new Set([...(saved.order||[]).map(category),...categories])].filter(id=>categories.includes(id)),
    disabled:categories.filter(id=>id==='室内环境'&&mode==='simple'
      // Old preferences merge at their first position; keep the group if any part was enabled.
      ?disabled.includes(id)||!saved.order?.includes(id)&&indoorCategories.every(old=>disabled.includes(old))
      :disabled.includes(id))};
}
export function assertTemplate(config) {
  if(!config||!Array.isArray(config.order)||!Array.isArray(config.disabled)||[...config.order,...config.disabled].some(id=>typeof id!=='string')||new Set(config.order).size!==config.order.length)throw Error('清单排序数据无效');
  if(!config.order.some(id=>(templateCategories.includes(id)||id==='室内环境')&&!config.disabled.includes(id)))throw Error('至少保留一个检查大项。');
}
export function moveItem(order,from,to) {
  const next=[...order];
  if(from<0||to<0||from>=next.length||to>=next.length)return next;
  next.splice(to,0,next.splice(from,1)[0]);return next;
}
