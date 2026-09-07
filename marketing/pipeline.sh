#!/usr/bin/env bash
# Marketing ffmpeg pipeline — redacts secrets before encode
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
src="${1:-$root/bench/cockpit/screenshots/t384u}"
out="${2:-$root/marketing/output}"
mkdir -p "$out"

shopt -s nullglob
for f in "$src"/*.{json,html,txt,md}; do
  base="$(basename "$f")"
  "$root/marketing/redact-secrets.sh" "$f" >"$out/redacted-$base"
done

if command -v ffmpeg >/dev/null 2>&1; then
  for vid in "$src"/*.{mp4,webm,mkv}; do
    [[ -f "$vid" ]] || continue
    ffmpeg -y -i "$vid" -vf "drawtext=text='cockpit':fontsize=24:fontcolor=cyan@0.5:x=10:y=10" \
      -c:v libx264 -preset fast "$out/$(basename "${vid%.*}")-marketing.mp4" 2>/dev/null || true
  done
fi

printf 'Marketing artifacts: %s\n' "$out"
ls -la "$out" 2>/dev/null || true
