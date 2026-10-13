import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
import {fileURLToPath,URL} from 'node:url';
export default defineConfig({
  base:'./',
  server:{proxy:{'/assistant-api':'http://127.0.0.1:3188'}},
  plugins:[react()],
  resolve:{alias:{'@':fileURLToPath(new URL('.',import.meta.url))}},
  build:{outDir:'dist',emptyOutDir:true},
});
