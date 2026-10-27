// Split plain speech into styled runs while revealing only complete Unicode characters.
export function speechParts(text, highlights=[], visibleCount=Infinity, icons={}) {
  const letters=Array.from(text||''),terms=(Array.isArray(highlights)?highlights:[])
    .filter(value=>typeof value==='string'&&value.length).map(value=>Array.from(value))
    .sort((a,b)=>b.length-a.length);
  const end=Math.max(0,Math.min(letters.length,visibleCount)),parts=[];
  for(let index=0;index<end;){
    const icon=icons?.[letters[index]];
    if(icon){parts.push({key:parts.length,text:letters[index],icon});index++;continue;}
    const term=terms.find(value=>value.every((letter,offset)=>letters[index+offset]===letter));
    const emphasis=!!term,next=Math.min(end,index+(term?.length||1));
    const value=letters.slice(index,next).join(''),last=parts[parts.length-1];
    if(last&&!last.icon&&last.emphasis===emphasis)last.text+=value;
    else parts.push({key:parts.length,text:value,emphasis});
    index=next;
  }
  return parts;
}
