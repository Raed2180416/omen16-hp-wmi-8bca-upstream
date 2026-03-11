# Upstreaming process and review expectations

## Patch being submitted

`platform/x86: hp-wmi: Add Omen 16-xf0xxx (8BCA) support`

Minimal change:

- add `DMI_MATCH(DMI_BOARD_NAME, "8BCA")`
- map to `&omen_v1_thermal_params`

## Recipient set

- `platform-driver-x86@vger.kernel.org`
- `linux-kernel@vger.kernel.org`
- `hansg@kernel.org`
- `ilpo.jarvinen@linux.intel.com`

## What maintainers may request in v2

Typical requests for this class of patch:

1. **Commit message tightening**
   - shorten/clarify rationale
   - remove or trim long validation bullets

2. **DMI table ordering/style adjustments**
   - keep board IDs in preferred order in `victus_s_thermal_profile_boards[]`

3. **Evidence clarifications**
   - explicit board/BIOS in commit text
   - confirm that mapped params are `omen_v1_thermal_params`

4. **Tag changes**
   - add `Tested-by` / `Reported-by` if appropriate

5. **No functional changes, only wording**
   - many v2 rounds are purely message/style polish

## v2 mechanics

- keep same logical change unless asked otherwise
- regenerate patch with subject prefix `[PATCH v2]`
- include short changelog under `---`, e.g.:

```text
v2:
- reword commit message for brevity
- reorder DMI entry in victus_s_thermal_profile_boards[]
```

## Deterministic send checklist

1. `checkpatch` clean on the generated patch
2. recipients from `scripts/get_maintainer.pl`
3. plain-text email, no HTML reformat
4. preserve exact diff and whitespace
5. keep `Signed-off-by`

## Realistic timeline

- first review: hours to days
- accepted: can take one or more cycles depending on maintainer load
