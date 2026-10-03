// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe pinokio/start.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: daemon:true; HOST 127.0.0.1; Cockpit env keys; Ready regex; sharing sentinels..

module.exports = {
  daemon: true,
  run: [
    {
      method: 'shell.run',
      params: {
        path: '..',
        env: {
          HOST: '127.0.0.1',
          COCKPIT_LOCAL_TRUST: '1',
          PORT: '{{port}}',
          OPENAI_API_KEY: '{{env.OPENAI_API_KEY || ""}}',
          ANTHROPIC_API_KEY: '{{env.ANTHROPIC_API_KEY || ""}}',
          XAI_API_KEY: '{{env.XAI_API_KEY || ""}}',
          COCKPIT_NTFY_TOPIC: '{{env.COCKPIT_NTFY_TOPIC || ""}}',
          COCKPIT_NOTIFY_KEY: '{{env.COCKPIT_NOTIFY_KEY || ""}}',
          COCKPIT_TELEGRAM_BOT_TOKEN: '{{env.COCKPIT_TELEGRAM_BOT_TOKEN || ""}}',
          PINOKIO_SHARE_CLOUDFLARE: '{{env.PINOKIO_SHARE_CLOUDFLARE || "false"}}',
          PINOKIO_SHARE_LOCAL: '{{env.PINOKIO_SHARE_LOCAL || "false"}}',
          PINOKIO_SHARE_VAR: '{{env.PINOKIO_SHARE_VAR || "__cockpit_sharing_disabled__"}}',
        },
        message: 'node scripts/pinokio-start.mjs',
        on: [{
          event: '/\\[Pinokio\\] Ready at (http:\\/\\/127\\.0\\.0\\.1:[0-9]+\\/)/',
          done: true,
        }],
      },
    },
    {
      method: 'local.set',
      params: {
        url: '{{input.event[1]}}',
      },
    },
  ],
};
