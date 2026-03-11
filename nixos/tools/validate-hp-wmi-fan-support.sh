#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
WARN=0

ok() {
  printf '[PASS] %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  WARN=$((WARN + 1))
}

section() {
  printf '\n== %s ==\n' "$1"
}

CURRENT_SYSTEM="$(readlink -f /run/current-system)"
KERNEL_LOG="$(journalctl -k -b --no-pager)"
PLATFORM_CHOICES="$(< /sys/firmware/acpi/platform_profile_choices)"
EXPECTED_BOARD="8BCA"
EXPECTED_BIOS_VERSION="F.30"
EXPECTED_BIOS_DATE="07/10/2025"
BOARD_NAME="$(< /sys/class/dmi/id/board_name)"
BIOS_VERSION="$(< /sys/class/dmi/id/bios_version)"
BIOS_DATE="$(< /sys/class/dmi/id/bios_date)"

HWMON_DIR=""
for candidate in /sys/devices/platform/hp-wmi/hwmon/hwmon*; do
  if [[ -d "$candidate" ]] && [[ -f "$candidate/name" ]] && grep -qx 'hp' "$candidate/name"; then
    HWMON_DIR="$candidate"
    break
  fi
done

section "Host"
printf 'board: %s\n' "$BOARD_NAME"
printf 'bios: %s (%s)\n' "$BIOS_VERSION" "$BIOS_DATE"
printf 'kernel: %s\n' "$(uname -r)"
printf 'system: %s\n' "$CURRENT_SYSTEM"
if [[ "$BOARD_NAME" == "$EXPECTED_BOARD" ]]; then
  ok "board matches expected OMEN 16 board ID"
else
  fail "board differs from expected OMEN 16 board ID"
fi

if [[ "$BIOS_VERSION" == "$EXPECTED_BIOS_VERSION" && "$BIOS_DATE" == "$EXPECTED_BIOS_DATE" ]]; then
  ok "BIOS matches pinned validated firmware"
else
  fail "BIOS differs from pinned validated firmware"
fi

section "Platform Profile"
printf 'choices: %s\n' "$PLATFORM_CHOICES"
if [[ "$PLATFORM_CHOICES" == "low-power balanced performance" ]]; then
  ok "platform profile choices match expected OMEN 16 set"
else
  fail "platform profile choices differ from expected OMEN 16 set"
fi

section "Hwmon"
if [[ -n "$HWMON_DIR" ]]; then
  ok "hp-wmi hwmon path found at $HWMON_DIR"
else
  fail "hp-wmi hwmon path not found"
fi

if [[ -n "$HWMON_DIR" ]]; then
  for node in fan1_input fan2_input pwm1_enable pwm1; do
    if [[ -e "$HWMON_DIR/$node" ]]; then
      ok "$node present"
    else
      fail "$node missing"
    fi
  done

  for node in fan1_input fan2_input pwm1_enable pwm1; do
    if [[ -r "$HWMON_DIR/$node" ]]; then
      printf '%s=%s\n' "$node" "$(cat "$HWMON_DIR/$node")"
    fi
  done
fi

section "Kernel Log"
if grep -Eq 'ACPI Error|ACPI BIOS Error' <<<"$KERNEL_LOG"; then
  warn "generic ACPI errors are present; inspect hp-wmi-adjacent lines if runtime behavior regresses"
else
  ok "kernel log has no generic ACPI errors"
fi

if grep -Eq 'hp_wmi|hp-wmi' <<<"$KERNEL_LOG"; then
  ok "kernel log contains hp-wmi lines for this boot"
else
  warn "no hp-wmi kernel log lines found for this boot"
fi

section "Manual Test"
if [[ -n "$HWMON_DIR" ]] && [[ -e "$HWMON_DIR/pwm1" ]]; then
  printf 'Run these exact commands as root, in order:\n'
  printf '  echo 1 > %s/pwm1_enable\n' "$HWMON_DIR"
  printf '  echo 255 > %s/pwm1\n' "$HWMON_DIR"
  printf '  sleep 5\n'
  printf '  cat %s/fan1_input %s/fan2_input %s/pwm1 %s/pwm1_enable\n' "$HWMON_DIR" "$HWMON_DIR" "$HWMON_DIR" "$HWMON_DIR"
  printf '  echo 220 > %s/pwm1\n' "$HWMON_DIR"
  printf '  sleep 5\n'
  printf '  echo 2 > %s/pwm1_enable\n' "$HWMON_DIR"
else
  warn "manual fan-control commands not emitted because pwm1 is unavailable"
fi

printf '\nSummary: PASS=%d WARN=%d FAIL=%d\n' "$PASS" "$WARN" "$FAIL"
if ((FAIL > 0)); then
  exit 1
fi
