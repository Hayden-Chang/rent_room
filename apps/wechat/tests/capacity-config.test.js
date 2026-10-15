import {it,expect} from 'vitest';
import {capacityEndpoint} from '../scripts/capacity-config.mjs';

it('only embeds an HTTPS capacity endpoint without credentials in the client build',()=>{
 expect(capacityEndpoint()).toBe('');expect(capacityEndpoint(' https://api.example.com/api/rent-room/ ')).toBe('https://api.example.com/api/rent-room');
 for(const value of ['http://api.example.com','https://user:secret@api.example.com','https://api.example.com?key=secret','https://api.example.com#key','https://[broken','https://api.exa\nmple.com'])expect(()=>capacityEndpoint(value)).toThrow();
});
