# HP OMEN 16 (8BCA) Linux fan-control upstreaming kit

Deterministic artifacts for enabling and upstreaming `hp-wmi` fan/thermal support on **HP OMEN 16-xf0xxx, board 8BCA**.

## Scope

This repository captures:

- the minimal upstream patch for board `8BCA`
- NixOS integration used to keep the patch stack deterministic
- preflight/validation scripts used to fail early on breakage
- hardware validation evidence collected during bring-up

It does **not** include proprietary binaries.

## Machine profile (validated target)

- Model: HP OMEN 16-xf0xxx
- Board ID: `8BCA`
- BIOS: `F.30` (`07/10/2025`)
- Kernel family used during integration: `linux-zen 6.18.7`

## What is proven on this machine

- `hp-wmi` exports RPMs for both fans (`fan1_input`, `fan2_input`)
- manual control path works via `pwm1_enable` + `pwm1`
- ACPI platform profile exposes `low-power balanced performance`
- manual write test changes actual RPMs

Observed runtime probe values (captured during validation):

- WMI query `0x10`: `fan_count=2`
- WMI query `0x2D`: stable, non-zero fan bytes
- WMI query `0x2F`: header `unknown=2 entries=41 size=125`

## Repository layout

- `patches/0001-platform-x86-hp-wmi-Add-Omen-16-xf0xxx-8BCA-support.patch`
- `nixos/hosts/omen16/patches/hp-wmi/` (patch stack 10..50)
- `nixos/hosts/omen16/hp-wmi-fan-support-lib.nix` (auto-skip already-upstream patches)
- `nixos/hosts/omen16/hp-wmi-preflight-check.nix` (dry-apply + compile `hp-wmi.o`)
- `nixos/tools/hp-wmi-preflight.sh`
- `nixos/tools/rebuild-omen16-hp-wmi.sh`
- `nixos/tools/validate-hp-wmi-fan-support.sh`
- `docs/REVERSE_ENGINEERING_NOTES.md`
- `docs/UPSTREAMING.md`

## Deterministic workflow

1. `hp-wmi` preflight check runs first.
2. Rebuild script verifies board/BIOS guardrails.
3. If patching conflicts, build fails before full kernel compile.
4. Runtime validation confirms hwmon nodes and profile behavior.
5. Minimal upstream patch (`8BCA` DMI mapping) is mailed to kernel lists.

## Current upstream status

As of 2026-03-11:

- Larger Victus/OMEN support series is already in upstream linux `master`.
- Local board quirk still required: `DMI_BOARD_NAME = "8BCA"` -> `omen_v1_thermal_params`.

## License

Follow upstream Linux patch licensing and contribution conventions (`Signed-off-by`).
