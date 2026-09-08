// Isolated runtime compatibility check; no network or persistent data.
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../backend-api/package.json', import.meta.url));
const { Miniflare, convertV4MiniflareOptions } = require('miniflare');
const mf = new Miniflare(convertV4MiniflareOptions({ name: 'analysis',
  modules: true,
  compatibilityDate: '2026-09-03',
  script: `export default { async fetch() {
    try {
      const key = await crypto.subtle.importKey('raw', new TextEncoder().encode('987654'), 'PBKDF2', false, ['deriveBits']);
      await crypto.subtle.deriveBits({name:'PBKDF2', hash:'SHA-256', salt:new Uint8Array(16), iterations:120000},key,256);
      return Response.json({pbkdf2Iterations:120000,ok:true});
    } catch(error) {return Response.json({pbkdf2Iterations:120000,ok:false,name:error.name,message:error.message});}
  } }`,
}));
try { console.log(await (await mf.dispatchFetch('http://analysis.local')).text()); }
finally { await mf.dispose(); }
