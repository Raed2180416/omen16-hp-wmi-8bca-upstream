#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-/etc/nixos}"
FLAKE_REF="${REPO_ROOT}#checks.x86_64-linux.omen16-hp-wmi-preflight"

OUT_PATH="$(
  nix build --no-link --print-build-logs --json "$FLAKE_REF" \
    | python -c 'import json, sys; print(json.load(sys.stdin)[0]["outputs"]["out"])'
)"

cat "${OUT_PATH}/report.txt"
