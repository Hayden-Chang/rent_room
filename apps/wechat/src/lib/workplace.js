import {point,keepsLocation} from './places.js';

export function updateWorkplace(settings,address) {
  const base=settings.workplaceLocationAddress||settings.workplace||'';
  const anchor=point(settings.workplaceLocationAnchor)||point(settings.workplaceLocation);
  settings.workplace=address;
  settings.workplaceLocation=anchor&&keepsLocation(address,base)?anchor:null;
  if(anchor){settings.workplaceLocationAnchor=anchor;settings.workplaceLocationAddress=base;}
}

export function selectWorkplace(settings,place) {
  const location=point(place?.location),address=String(place?.address||'').trim();
  if(!location||!address)throw Error('地点信息不完整，请重新选择');
  Object.assign(settings,{workplace:address,workplaceLocation:location,workplaceLocationAnchor:location,workplaceLocationAddress:address});
}

export function clearWorkplace(settings) {
  settings.workplace='';
  for(const key of ['workplaceLocation','workplaceLocationAnchor','workplaceLocationAddress'])delete settings[key];
}
