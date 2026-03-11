{ lib }:
{
  kernelSrc,
  patchDir,
}:
let
  hpWmiSourcePath = kernelSrc + "/drivers/platform/x86/hp/hp-wmi.c";

  ensure =
    condition: message:
    if condition then
      null
    else
      throw message;

  _sourceExists = ensure (builtins.pathExists hpWmiSourcePath) ''
    omen16 hp-wmi support: expected kernel source at ${toString hpWmiSourcePath}, but it does not exist.
  '';

  hpWmiSource = builtins.readFile hpWmiSourcePath;
  has = needle: lib.hasInfix needle hpWmiSource;

  markers = {
    /*
     * Upstream hp-wmi names this newer shared OMEN/Victus codepath
     * "victus_s". Board 8BCA is still an OMEN 16 and is wired into this
     * path with omen_v1 thermal parameters.
     */
    hasVictusSystemIdTable = has "static const struct dmi_system_id victus_s_thermal_profile_boards[] __initconst";
    hasThermalProfileParams = has "struct thermal_profile_params {";
    hasActiveThermalProfileParams = has "static struct thermal_profile_params *active_thermal_profile_params;";
    hasVictusBoardInitFlag = has "static bool is_victus_s_board;";
    hasEcTpOffset = has "ec_tp_offset";
    hasPlatformProfileVictusSGetEc = has "platform_profile_victus_s_get_ec(";
    hasFanTableQuery = has "HPWMI_VICTUS_S_GET_FAN_TABLE_QUERY";
    hasHwmonPriv = has "struct hp_wmi_hwmon_priv {";
    hasPwmInput = has "HWMON_PWM_ENABLE | HWMON_PWM_INPUT";
    hasKeepAliveDwork = has "keep_alive_dwork";
    hasKeepAliveHandler = has "hp_wmi_hwmon_keep_alive_handler(";
    has8BCAQuirk = has "DMI_MATCH(DMI_BOARD_NAME, \"8BCA\")";
  };

  _thermalStateValid = ensure (
    (markers.hasThermalProfileParams == markers.hasActiveThermalProfileParams)
    && (markers.hasThermalProfileParams == markers.hasVictusBoardInitFlag)
  ) ''
    omen16 hp-wmi support: hp-wmi.c has a partial thermal-profile-params state.
    Expected thermal-profile params, active pointer, and Victus-S init flag markers to move together.
  '';

  _ecStateValid = ensure (
    (!markers.hasEcTpOffset && !markers.hasPlatformProfileVictusSGetEc)
    || (markers.hasEcTpOffset && markers.hasPlatformProfileVictusSGetEc)
  ) ''
    omen16 hp-wmi support: hp-wmi.c has a partial Victus-S EC thermal-profile readback state.
    Expected ec_tp_offset support and platform_profile_victus_s_get_ec() to appear together.
  '';

  _fanStateValid = ensure (
    (!markers.hasFanTableQuery && !markers.hasHwmonPriv && !markers.hasPwmInput && !markers.hasKeepAliveDwork && !markers.hasKeepAliveHandler)
    || (markers.hasFanTableQuery && markers.hasHwmonPriv)
  ) ''
    omen16 hp-wmi support: hp-wmi.c has a partial manual-fan-control state.
    Expected Victus-S fan-table query and hwmon private state to be present together.
  '';

  _keepAliveStateValid = ensure (
    (!markers.hasKeepAliveDwork && !markers.hasKeepAliveHandler)
    || (markers.hasKeepAliveDwork && markers.hasKeepAliveHandler)
  ) ''
    omen16 hp-wmi support: hp-wmi.c has a partial keep-alive state.
    Expected delayed work state and the keep-alive handler to appear together.
  '';

  _8bcaStateValid = ensure (!markers.has8BCAQuirk || markers.hasVictusSystemIdTable) ''
    omen16 hp-wmi support: hp-wmi.c already mentions board 8BCA, but the Victus-S DMI table marker is missing.
    Source layout changed unexpectedly; drop or refresh the local 8BCA quirk before rebuilding.
  '';

  _8bcaNotUpstreamYet = ensure (!markers.has8BCAQuirk) ''
    omen16 hp-wmi support: board 8BCA already exists in upstream hp-wmi.c.
    Drop the local 8BCA quirk patch and refresh hosts/omen16/hp-wmi-fan-support-lib.nix before rebuilding.
  '';

  mkPatch =
    {
      name,
      relPath,
      state,
    }:
    {
      inherit name relPath state;
      patch = patchDir + "/${relPath}";
    };

  catalog = [
    (mkPatch {
      name = "hp-wmi-omen-v1-platform-profile-fix-backport";
      relPath = "10-hp-wmi-fix-platform-profile-values-for-omen-16-wf1xxx.patch";
      state =
        if markers.hasThermalProfileParams
           && markers.hasActiveThermalProfileParams
           && markers.hasVictusBoardInitFlag
           && markers.hasVictusSystemIdTable then
          "already-upstream"
        else
          "needed";
    })
    (mkPatch {
      name = "hp-wmi-omen-v1-ec-thermal-readback-backport";
      relPath = "20-hp-wmi-add-ec-offsets-to-read-victus-s-thermal-profile.patch";
      state =
        if markers.hasEcTpOffset && markers.hasPlatformProfileVictusSGetEc then
          "already-upstream"
        else
          "needed";
    })
    (mkPatch {
      name = "hp-wmi-omen-v1-manual-fan-control-backport";
      relPath = "30-hp-wmi-add-manual-fan-control-for-victus-s.patch";
      state =
        if markers.hasFanTableQuery && markers.hasHwmonPriv && markers.hasPwmInput then
          "already-upstream"
        else
          "needed";
    })
    (mkPatch {
      name = "hp-wmi-omen-v1-fan-keep-alive-backport";
      relPath = "40-hp-wmi-implement-fan-keep-alive.patch";
      state =
        if markers.hasKeepAliveDwork && markers.hasKeepAliveHandler then
          "already-upstream"
        else
          "needed";
    })
    (mkPatch {
      name = "hp-wmi-omen-16-xf0xxx-8bca-quirk";
      relPath = "50-hp-wmi-add-omen-16-xf0xxx-8bca-support.patch";
      state = "needed";
    })
  ];
in
{
  inherit hpWmiSourcePath markers catalog;
  kernelPatches = map (patch: { inherit (patch) name patch; }) (lib.filter (patch: patch.state == "needed") catalog);
}
