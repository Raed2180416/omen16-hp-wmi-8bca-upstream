#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Requires: gh auth login
# Example:
#   gh auth login -h github.com
#   ./publish-github.sh

gh repo create omen16-hp-wmi-8bca-upstream \
  --public \
  --source=. \
  --remote=origin \
  --push
