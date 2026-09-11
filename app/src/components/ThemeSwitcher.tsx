import { THEMES, type CockpitTheme, saveTheme } from "../lib/theme";
import styles from "./ThemeSwitcher.module.css";

interface ThemeSwitcherProps {
  value: CockpitTheme;
  onChange: (theme: CockpitTheme) => void;
  compact?: boolean;
}

export function ThemeSwitcher({ value, onChange, compact }: ThemeSwitcherProps) {
  return (
    <div className={styles.root} role="group" aria-label="Theme switcher">
      {!compact && <span className={styles.label}>Theme</span>}
      <div className={styles.options}>
        {THEMES.map((t) => (
          <button
            key={t.id}
            type="button"
            className={`${styles.option} ${value === t.id ? styles.optionActive : ""}`}
            onClick={() => {
              saveTheme(t.id);
              onChange(t.id);
            }}
          >
            {t.label}
          </button>
        ))}
      </div>
    </div>
  );
}
