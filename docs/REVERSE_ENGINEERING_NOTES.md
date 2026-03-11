# Reverse-engineering notes (bounded to verified facts)

This document intentionally records only findings that were either:

1. reproduced through Linux runtime validation on board `8BCA`, or
2. reflected in concrete code/patch artifacts in this repository.

## Source of findings

- Runtime behavior observed on HP OMEN 16-xf0xxx (`8BCA`).
- `hp-wmi` Victus-S path behavior in Linux kernel source/patch stack.
- Validation commands and outputs from bring-up sessions.

## Confirmed protocol-level findings

The working fan path aligns with Victus-S query flow:

- `0x10` reports fan count (`2`).
- `0x2D` returns stable non-zero fan payload bytes.
- `0x2F` fan table query returns header with `unknown=2`, `entries=41`, `size=125`.

These findings are consistent with enabling:

- fan RPM reporting for both fans
- shared manual PWM control via `pwm1`
- keep-alive behavior needed by Victus-S fan control

## Confirmed sysfs/hwmon findings

On validated boot:

- hwmon path: `/sys/devices/platform/hp-wmi/hwmon/hwmon7`
- nodes present: `fan1_input`, `fan2_input`, `pwm1`, `pwm1_enable`

Manual test (root) changed real RPMs (example values observed):

- `fan1_input ~5300`
- `fan2_input ~5700`
- with `pwm1_enable=1` and high `pwm1`

## Important constraint

The currently exposed interface is **shared control**, not independent per-fan control:

- one writable `pwm1`
- two RPM readouts

Therefore UI/policy should model one manual fan target + two telemetry channels.

