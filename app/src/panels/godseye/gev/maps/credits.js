// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/maps/credits.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: cockpit panel path.
import * as Cesium from 'cesium';

/** Static credits follow the source actually on screen, including fallback. */
export function createMapCredits(viewer) {
  let active = null;
  let markup = null;
  return {
    show(html) {
      if (html === markup) return;
      const display = viewer?.scene?.frameState?.creditDisplay;
      if (!display) return;
      try {
        if (active) display.removeStaticCredit(active);
        active = html ? new Cesium.Credit(html, true) : null;
        markup = html;
        if (active) display.addStaticCredit(active);
      } catch {
        /* Switching remains usable on older credit displays. */
      }
    },
    destroy() {
      this.show(null);
    },
  };
}
