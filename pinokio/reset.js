// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe pinokio/reset.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Near verbatim; path ...

module.exports = {
  run: [
    {
      method: 'shell.run',
      params: {
        path: '..',
        message: 'node scripts/pinokio-reset.mjs',
      },
    },
  ],
};
