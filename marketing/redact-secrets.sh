#!/usr/bin/env bash
# Redact secrets from marketing capture sources before ffmpeg pipeline
set -euo pipefail

in="${1:?usage: redact-secrets.sh INPUT > OUTPUT}"
patterns=(
  'gho_[A-Za-z0-9_]+'
  'ghp_[A-Za-z0-9_]+'
  'ghu_[A-Za-z0-9_]+'
  'ghs_[A-Za-z0-9_]+'
  'sk-[A-Za-z0-9_-]+'
  'xox[baprs]-[A-Za-z0-9-]+'
  'Bearer [A-Za-z0-9._-]+'
  'api[_-]?key[=:][[:space:]]*[A-Za-z0-9_-]+'
)

text="$(cat "$in")"
for p in "${patterns[@]}"; do
  text="$(printf '%s' "$text" | sed -E "s/${p}/[REDACTED]/g")"
done
printf '%s\n' "$text"
