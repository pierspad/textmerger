import { svelte } from '@sveltejs/vite-plugin-svelte'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [svelte()],
  base: './',
  clearScreen: false,
  server: {
    port: process.env.PORT ? parseInt(process.env.PORT) : 5174,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
  build: {
    sourcemap: false,
    minify: 'esbuild',
  },
})
