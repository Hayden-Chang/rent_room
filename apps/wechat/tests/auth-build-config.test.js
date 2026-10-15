import {it,expect} from 'vitest';
import {authUrl} from '../scripts/auth-config.mjs';
it('accepts only HTTPS domain endpoints without embedded credentials',()=>{
  expect(authUrl(' https://api.keeline.xyz/api/rent-room/auth/wechat ')).toBe('https://api.keeline.xyz/api/rent-room/auth/wechat');
  expect(authUrl()).toBe('');
  for(const value of ['http://api.example.com/login','https://127.0.0.1/login','https://localhost/login','https://test.localhost/login','https://user:secret@api.example.com/login','https://api.example.com/login?secret=x','https://api.example.com/login#hash'])expect(()=>authUrl(value)).toThrow();
});
