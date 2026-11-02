import {it,expect} from 'vitest';
import {apiUrl} from '../scripts/api-config.mjs';
import {buildSync} from 'esbuild';
import vm from 'node:vm';
import fs from 'node:fs';
import {accountWx} from './helpers/account-fixture.js';

it('logs in through the deployed backend when a preview build has no API override',async()=>{
  const m=accountWx();let app;
  const code=buildSync({entryPoints:['src/app.js'],bundle:true,write:false,format:'cjs',platform:'browser',define:{__WECHAT_API_URL__:JSON.stringify(apiUrl())}}).outputFiles[0].text;
  vm.runInNewContext(code,{wx:m.wx,App:value=>{app=value;},setTimeout,clearTimeout});app.onLaunch();
  expect(await app.auth.login()).toBe(true);
  expect(m.calls.find(call=>call.url?.endsWith('/session'))).toEqual({url:'https://api.keeline.xyz/api/rent-room/session',method:'POST',data:{code:'test-one-time-code'}});
  expect(app.auth.isAuthenticated()).toBe(true);
});

it('packages runtime icons and their license without duplicate vector sources',()=>{
  expect(fs.existsSync('dist/assets/icons/home-default.svg')).toBe(false);
  for(const file of ['home-default.png','account.svg','LUCIDE-LICENSE.txt'])expect(fs.existsSync('dist/assets/icons/'+file)).toBe(true);
});

it('accepts only HTTPS domain endpoints without embedded credentials',()=>{
  expect(apiUrl(' https://api.keeline.xyz/api/rent-room ')).toBe('https://api.keeline.xyz/api/rent-room');
  expect(apiUrl('')).toBe('');
  expect(apiUrl('   ')).toBe('');
  expect(apiUrl('https://preview.example.com/api/rent-room/')).toBe('https://preview.example.com/api/rent-room');
  for(const value of ['http://api.example.com/login','https://127.0.0.1/login','https://localhost/login','https://test.localhost/login','https://user:secret@api.example.com/login','https://api.example.com/login?secret=x','https://api.example.com/login#hash'])expect(()=>apiUrl(value)).toThrow();
});
