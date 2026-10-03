// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe pinokio/pinokio.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Title Cockpit; Open Cockpit URL; Doctor menu item..

module.exports = {
  version: '3.6',
  title: 'Cockpit',
  description: 'tmux workspace for local coding agents — keyless-first onboarding.',
  menu: async (kernel, info) => {
    const installed = await kernel.exists(__dirname, '.installed');
    const installing = info.running('install.js');
    const starting = info.running('start.js');
    const updating = info.running('update.js');
    const resetting = info.running('reset.js');

    if (installing || updating || resetting) {
      const href = installing ? 'install.js' : updating ? 'update.js' : 'reset.js';
      const text = installing ? 'Installing' : updating ? 'Updating' : 'Resetting';
      return [{ default: true, icon: 'fa-solid fa-terminal', text, href }];
    }

    if (!installed) {
      return [{ default: true, icon: 'fa-solid fa-download', text: 'Install', href: 'install.js' }];
    }

    if (starting) {
      const local = info.local('start.js');
      if (local?.url) {
        return [
          { default: true, icon: 'fa-solid fa-rocket', text: 'Open Cockpit', href: local.url },
          { icon: 'fa-solid fa-terminal', text: 'Server', href: 'start.js' },
          { icon: 'fa-solid fa-stethoscope', text: 'Doctor', href: '../bin/cockpit-doctor' },
        ];
      }
      return [{ default: true, icon: 'fa-solid fa-terminal', text: 'Starting', href: 'start.js' }];
    }

    return [
      { default: true, icon: 'fa-solid fa-power-off', text: 'Start', href: 'start.js' },
      { icon: 'fa-solid fa-stethoscope', text: 'Doctor', href: '../bin/cockpit-doctor' },
      { icon: 'fa-solid fa-arrows-rotate', text: 'Update', href: 'update.js' },
      { icon: 'fa-solid fa-broom', text: 'Repair installation', href: 'reset.js' },
    ];
  },
};
