import styles from "../../panels/FilesPanel.module.css";

export function FilesPanelContent() {
  return (
    <div className={styles.root}>
      <p>Neovim follower — parallel TUI via <span className={styles.code}>cockpit files</span>.</p>
      <ul className={styles.list}>
        <li>Event-driven file watch (inotify policy from cockpit-lib)</li>
        <li>Follows agent-written paths</li>
        <li>Foot size-owning on dezohost · Funnel OFF · Serve OFF</li>
      </ul>
    </div>
  );
}
