// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe pinokio/update.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Cockpit env forwarding; runs pinokio-update.mjs..

module.exports = {
  run: [
    {
      method: 'shell.run',
      params: {
        path: '..',
        env: {
          OPENAI_API_KEY: '{{env.OPENAI_API_KEY || ""}}',
          ANTHROPIC_API_KEY: '{{env.ANTHROPIC_API_KEY || ""}}',
          XAI_API_KEY: '{{env.XAI_API_KEY || ""}}',
          COCKPIT_NTFY_TOPIC: '{{env.COCKPIT_NTFY_TOPIC || ""}}',
          COCKPIT_NOTIFY_KEY: '{{env.COCKPIT_NOTIFY_KEY || ""}}',
          COCKPIT_TELEGRAM_BOT_TOKEN: '{{env.COCKPIT_TELEGRAM_BOT_TOKEN || ""}}',
        },
        message: 'node scripts/pinokio-update.mjs',
      },
    },
  ],
};
