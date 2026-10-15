import {isIP} from 'node:net';

export function apiUrl(value='') {
  if(!value.trim())return ''; // Unconfigured builds fail closed at the login screen.
  const url=new URL(value.trim());
  if(/\s/.test(value.trim())||url.protocol!=='https:'||url.username||url.password||url.hash||url.search||isIP(url.hostname)||!url.hostname.includes('.')||url.hostname.endsWith('.localhost'))throw Error('WECHAT_API_URL must be an HTTPS domain URL without credentials, query or fragment');
  return url.href.replace(/\/$/,'');
}
