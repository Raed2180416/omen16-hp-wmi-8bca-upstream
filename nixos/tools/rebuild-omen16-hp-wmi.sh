#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: rebuild-omen16-hp-wmi.sh [switch|boot|test|build|dry-build|dry-run] [nixos-rebuild options...]
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ACTION="${1:-switch}"
case "$ACTION" in
  switch|boot|test|build|dry-build|dry-run) ;;
  *)
    usage >&2
    exit 1
    ;;
esac

if [[ $# -gt 0 ]]; then
  shift
fi

REPO_ROOT="/etc/nixos"
HOST="omen16"
EXPECTED_BOARD="8BCA"
EXPECTED_BIOS_VERSION="F.30"
EXPECTED_BIOS_DATE="07/10/2025"
AS_ROOT=()

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  AS_ROOT=(sudo)
fi

BOARD_NAME="$(< /sys/class/dmi/id/board_name)"
BIOS_VERSION="$(< /sys/class/dmi/id/bios_version)"
BIOS_DATE="$(< /sys/class/dmi/id/bios_date)"

if [[ "$BOARD_NAME" != "$EXPECTED_BOARD" ]]; then
  printf 'refusing rebuild: expected board %s, found %s\n' "$EXPECTED_BOARD" "$BOARD_NAME" >&2
  exit 1
fi

if [[ "$BIOS_VERSION" != "$EXPECTED_BIOS_VERSION" || "$BIOS_DATE" != "$EXPECTED_BIOS_DATE" ]]; then
  printf 'refusing rebuild: expected BIOS %s (%s), found %s (%s)\n' \
    "$EXPECTED_BIOS_VERSION" "$EXPECTED_BIOS_DATE" "$BIOS_VERSION" "$BIOS_DATE" >&2
  exit 1
fi

"${REPO_ROOT}/tools/hp-wmi-preflight.sh" "$REPO_ROOT"

TARGET_KERNEL_OUT="$(
  nix eval --raw "${REPO_ROOT}#nixosConfigurations.${HOST}.config.boot.kernelPackages.kernel.outPath"
)"
RUNNING_KERNEL_OUT="$(dirname "$(readlink -f /run/current-system/kernel)")"

guard_was_active=0

cleanup() {
  if (( guard_was_active )); then
    "${AS_ROOT[@]}" systemctl start nix-guard.service
  fi
}

trap cleanup EXIT INT TERM

if [[ "$TARGET_KERNEL_OUT" == "$RUNNING_KERNEL_OUT" ]]; then
  printf 'kernel derivation unchanged; running standard rebuild with existing host limits\n'
  exec "${AS_ROOT[@]}" nixos-rebuild --print-build-logs --flake "${REPO_ROOT}#${HOST}" "$ACTION" "$@"
fi

printf 'kernel derivation changed; entering temporary big-build mode (--cores 0 --max-jobs 1)\n'
if systemctl is-active --quiet nix-guard.service; then
  "${AS_ROOT[@]}" systemctl stop nix-guard.service
  guard_was_active=1
fi

"${AS_ROOT[@]}" nixos-rebuild --print-build-logs --cores 0 --max-jobs 1 --flake "${REPO_ROOT}#${HOST}" "$ACTION" "$@"
