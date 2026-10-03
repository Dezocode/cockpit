// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe pinokio/install.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Env list = Cockpit KEY_SETUP_KEYS; runs pinokio-install.mjs..

module.exports = {
  run: [
    {
      when: "{{!kernel.exists(cwd, 'ENVIRONMENT')}}",
      method: 'fs.copy',
      params: {
        src: '_ENVIRONMENT',
        dest: 'ENVIRONMENT',
      },
    },
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
          PINOKIO_SHARE_CLOUDFLARE: '{{env.PINOKIO_SHARE_CLOUDFLARE || "false"}}',
          PINOKIO_SHARE_LOCAL: '{{env.PINOKIO_SHARE_LOCAL || "false"}}',
          PINOKIO_SHARE_VAR: '{{env.PINOKIO_SHARE_VAR || "__cockpit_sharing_disabled__"}}',
        },
        message: 'node scripts/pinokio-install.mjs',
      },
    },
  ],
};
