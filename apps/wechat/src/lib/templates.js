import templateCategories from './template-categories.json' with {type:'json'};

export {templateCategories};
export function templateConfig(settings={},mode='detailed') {
  const saved=settings.templates?.[mode]||{};
  return {order:[...new Set([...(saved.order||[]),...templateCategories])].filter(id=>templateCategories.includes(id)),
    disabled:(saved.disabled||[]).filter(id=>templateCategories.includes(id))};
}
export function assertTemplate(config) {
  if(!config||!Array.isArray(config.order)||!Array.isArray(config.disabled)||[...config.order,...config.disabled].some(id=>typeof id!=='string')||new Set(config.order).size!==config.order.length)throw Error('清单排序数据无效');
  if(!config.order.some(id=>templateCategories.includes(id)&&!config.disabled.includes(id)))throw Error('至少保留一个检查大项。');
}
export function moveItem(order,from,to) {
  const next=[...order];
  if(from<0||to<0||from>=next.length||to>=next.length)return next;
  next.splice(to,0,next.splice(from,1)[0]);return next;
}
