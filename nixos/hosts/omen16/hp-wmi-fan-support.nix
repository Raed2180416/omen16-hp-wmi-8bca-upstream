{ lib, pkgs, ... }:
let
  # Upstream hp-wmi groups this newer shared OMEN/Victus implementation under
  # the "victus_s" codepath. Board 8BCA stays on the OMEN-specific omen_v1
  # thermal profile within that upstream path.
  support =
    import ./hp-wmi-fan-support-lib.nix { inherit lib; } {
      kernelSrc = pkgs.linuxPackages_zen.kernel.src;
      patchDir = ./patches/hp-wmi;
    };
in
{
  boot.kernelPatches = lib.mkAfter support.kernelPatches;
}
