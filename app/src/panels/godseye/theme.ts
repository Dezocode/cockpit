const TOKEN_KEYS = {
  accent: "--cockpit-accent",
  active: "--cockpit-active",
  muted: "--cockpit-muted",
  text: "--cockpit-text",
  bg: "--cockpit-bg",
  border: "--cockpit-border",
  borderMuted: "--cockpit-border-muted",
} as const;

export type GodsEyeThemeColors = Record<keyof typeof TOKEN_KEYS, string>;

export function readGodsEyeThemeColors(root: HTMLElement = document.documentElement): GodsEyeThemeColors {
  const style = getComputedStyle(root);
  const out = {} as GodsEyeThemeColors;
  for (const [key, varName] of Object.entries(TOKEN_KEYS)) {
    out[key as keyof typeof TOKEN_KEYS] = style.getPropertyValue(varName).trim();
  }
  return out;
}

export function observeGodsEyeTheme(onChange: () => void): () => void {
  const observer = new MutationObserver((records) => {
    for (const record of records) {
      if (record.type === "attributes" && record.attributeName === "data-theme") {
        onChange();
        break;
      }
    }
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  return () => observer.disconnect();
}
