export function capacityEndpoint(value='') {
  const endpoint=value.trim().replace(/\/$/,'');
  if(!endpoint)return '';
  let url;
  try{url=new URL(endpoint);}catch{throw Error('Invalid WECHAT_CAPACITY_API service URL');}
  if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||/\s/.test(endpoint))throw Error('WECHAT_CAPACITY_API must be an HTTPS service URL without credentials or query');
  return endpoint;
}
