{
  pkgs,
  lib,
  kernel,
  support,
}:
let
  patchBundle = pkgs.linkFarm "omen16-hp-wmi-patches" (
    map (patch: {
      name = patch.relPath;
      path = patch.patch;
    }) support.catalog
  );

  catalogTsv = lib.concatStringsSep "\n" (
    map (patch: "${patch.name}\t${patch.state}\t${patch.relPath}") support.catalog
  );
in
pkgs.runCommand "omen16-hp-wmi-preflight"
  {
    nativeBuildInputs =
      [
        pkgs.coreutils
        pkgs.diffutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnumake
        pkgs.gnused
        pkgs.patch
        kernel.stdenv.cc
      ]
      ++ kernel.nativeBuildInputs
      ++ kernel.moduleBuildDependencies;
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    set -euo pipefail

    srcdir="$TMPDIR/linux-src"
    report="$TMPDIR/report.txt"
    patch_root="${patchBundle}"

    mkdir -p "$srcdir" "$out"
    cp -a --reflink=auto ${kernel.src}/. "$srcdir"/
    chmod -R u+w "$srcdir"
    patchShebangs "$srcdir"
    cp ${kernel.configfile} "$srcdir/.config"

    cat > "$TMPDIR/catalog.tsv" <<'EOF'
    ${catalogTsv}
    EOF

    {
      echo "omen16 hp-wmi preflight"
      echo "kernel=${kernel.name}"
      echo "source=${support.hpWmiSourcePath}"
      echo
      echo "patch-classification:"
    } > "$report"

    while IFS=$'\t' read -r name expected patch_file; do
      [[ -n "$name" ]] || continue
      patch_path="$patch_root/$patch_file"

      if [[ ! -r "$patch_path" ]]; then
        echo "preflight setup error: bundled patch $patch_path is missing" >&2
        cat "$report" >&2
        exit 1
      fi

      actual=""
      if patch --batch --forward --dry-run -p1 -d "$srcdir" < "$patch_path" >/dev/null 2>&1; then
        actual="needed"
      elif patch --batch --forward --dry-run -R -p1 -d "$srcdir" < "$patch_path" >/dev/null 2>&1; then
        actual="already-upstream"
      else
        actual="conflict"
      fi

      printf '%s: expected=%s actual=%s patch=%s\n' \
        "$name" "$expected" "$actual" "$patch_path" >> "$report"

      if [[ "$actual" == "conflict" ]]; then
        echo "preflight conflict: $name does not apply cleanly and does not reverse-apply either" >&2
        cat "$report" >&2
        exit 1
      fi

      if [[ "$actual" != "$expected" ]]; then
        echo "preflight mismatch: $name expected $expected but found $actual" >&2
        cat "$report" >&2
        exit 1
      fi

      if [[ "$actual" == "needed" ]]; then
        patch --batch --forward -p1 -d "$srcdir" < "$patch_path" >/dev/null
      fi
    done < "$TMPDIR/catalog.tsv"

    make -C "$srcdir" ARCH=x86_64 olddefconfig >/dev/null
    make -C "$srcdir" ARCH=x86_64 prepare modules_prepare >/dev/null
    make -C "$srcdir" ARCH=x86_64 drivers/platform/x86/hp/hp-wmi.o >/dev/null

    {
      echo
      echo "compile:"
      echo "status=ok"
      echo "object=drivers/platform/x86/hp/hp-wmi.o"
    } >> "$report"

    cp "$report" "$out/report.txt"
  ''
