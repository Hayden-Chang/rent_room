import {it,expect} from 'vitest';
import {apiUrl} from '../scripts/api-config.mjs';
it('accepts only HTTPS domain endpoints without embedded credentials',()=>{
  expect(apiUrl(' https://api.keeline.xyz/api/rent-room ')).toBe('https://api.keeline.xyz/api/rent-room');
  expect(apiUrl()).toBe('');
  for(const value of ['http://api.example.com/login','https://127.0.0.1/login','https://localhost/login','https://test.localhost/login','https://user:secret@api.example.com/login','https://api.example.com/login?secret=x','https://api.example.com/login#hash'])expect(()=>apiUrl(value)).toThrow();
});
