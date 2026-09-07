/** MODELS catalog — view `m` inside COMPUTERS (not a separate window). */
export function ModelsView() {
  const models = [
    "claude-sonnet-5",
    "composer-2.5",
    "gpt-5.6-sol-high",
    "gemini-3.8-flash-high",
    "frontier-subscription",
  ];
  return (
    <div className="flex-1 overflow-auto">
      <p className="mb-2 text-xs text-slate-400">
        Press <kbd className="rounded border border-slate-600 px-1">m</kbd> to toggle nodes ↔ models.
        Envelope: frontier_subscription — local OSS denied.
      </p>
      <ul className="space-y-1">
        {models.map((m) => (
          <li key={m} className="rounded border border-slate-700 px-2 py-1">
            {m}
          </li>
        ))}
      </ul>
    </div>
  );
}
