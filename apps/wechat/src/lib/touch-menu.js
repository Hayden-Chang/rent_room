export function touchMenuFrame(anchor,menu,bounds){
  const width=Math.min(menu.width,Math.max(0,bounds.width-24));
  const height=Math.min(menu.height,Math.max(0,bounds.height-24));
  return {left:Math.min(Math.max(anchor.x+8,12),bounds.width-12-width),
    top:Math.min(Math.max(anchor.y,12),bounds.height-12-height),width,height};
}

export function menuTouchPoint(event){
  const point=event.touches?.[0]||event.changedTouches?.[0]||event.detail;
  return {x:point.clientX??point.x,y:point.clientY??point.y};
}

export function closeTouchMenu(page,index=null){
  const resolve=page.touchMenuResolve;
  page.touchMenuResolve=null;
  if(page.data.touchMenu)page.setData({touchMenu:null});
  resolve?.(index===null?null:{tapIndex:index});
}

export function showTouchMenu(page,event,actions){
  closeTouchMenu(page);
  const anchor=menuTouchPoint(event);
  return new Promise(resolve=>{
    page.touchMenuResolve=resolve;
    page.setData({touchMenu:{anchor,actions}});
  });
}

export const touchMenuMethods={
  closeTouchMenu(){closeTouchMenu(this);},
  chooseTouchMenu(event){
    const index=event.detail.index;
    if(Number.isInteger(index)&&this.data.touchMenu?.actions[index])closeTouchMenu(this,index);
  }
};
