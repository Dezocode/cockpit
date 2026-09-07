export type CockpitTheme = "fieldset-dark" | "ghui-cyan" | "high-contrast";

export const THEME_STORAGE_KEY = "cockpit.theme";

export const THEMES: { id: CockpitTheme; label: string }[] = [
  { id: "fieldset-dark", label: "fieldset-dark" },
  { id: "ghui-cyan", label: "ghui-cyan" },
  { id: "high-contrast", label: "high-contrast" },
];

export function loadTheme(): CockpitTheme {
  if (typeof window === "undefined") return "fieldset-dark";
  const stored = localStorage.getItem(THEME_STORAGE_KEY) as CockpitTheme | null;
  if (stored && THEMES.some((t) => t.id === stored)) return stored;
  return "fieldset-dark";
}

export function saveTheme(theme: CockpitTheme): void {
  localStorage.setItem(THEME_STORAGE_KEY, theme);
  document.documentElement.dataset.theme = theme;
}

export function applyTheme(theme: CockpitTheme): void {
  document.documentElement.dataset.theme = theme;
}
