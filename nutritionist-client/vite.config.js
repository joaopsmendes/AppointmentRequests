import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // In development, requests to /api are forwarded to the Rails API.
    // The browser only talks to the Vite server (same origin), so no CORS is involved.
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
})
