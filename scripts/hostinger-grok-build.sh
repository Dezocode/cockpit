#!/usr/bin/env bash
# Gospel path name for curl one-liners — thin wrapper to deploy recipe.
exec "$(cd -- "$(dirname -- "$0")/.." && pwd)/deploy/hostinger-grok-build-install.sh" "$@"
