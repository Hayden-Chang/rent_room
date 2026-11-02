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
