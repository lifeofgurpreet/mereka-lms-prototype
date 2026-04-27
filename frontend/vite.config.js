import { defineConfig } from 'vite';

// Mereka LMS SPA — Vite configuration
//
// Dev server: http://localhost:5173
// Production build: ./dist/ (single-page app, deployed to Netlify)
//
// Environment variables (see .env.example):
//   VITE_OPENEDX_BASE_URL   — e.g. https://academyv2.mereka.io
//   VITE_OAUTH_CLIENT_ID    — Open edX OAuth2 application client_id
//   VITE_OAUTH_REDIRECT_URI — e.g. https://learn.mereka.org/auth/callback

export default defineConfig({
  root: '.',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: true,
    rollupOptions: {
      input: {
        main: 'index.html',
      },
    },
  },
  server: {
    port: 5173,
    host: true,
    open: true,
  },
  preview: {
    port: 4173,
    host: true,
  },
});
