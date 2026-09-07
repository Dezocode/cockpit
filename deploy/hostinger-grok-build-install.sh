#!/usr/bin/env bash
# Legacy wrapper — use scripts/hostinger-grok-build.sh
exec "$(cd -- "$(dirname -- "$0")/.." && pwd)/scripts/hostinger-grok-build.sh" "$@"
