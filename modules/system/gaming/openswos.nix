# OpenSWOS — C rewrite of Sensible World of Soccer 96/97 (Amiga), with online
# play. Not in nixpkgs. Exposed as `pkgs.openswos` by gamesOverlay in
# flake.nix, with `src` set to the non-flake input tracking upstream's main
# branch (no release tags; online peers need the same build, and the itch.io
# drops are cut from main).
#
# The game's own data (graphics, music, teams) is not free, so upstream's
# setup converts it from the player's copy. Here that copy is SWOS United's
# 25/26 season update for the Amiga (WHDLoad pack, sensiblesoccer.de), fed
# through upstream's swosdata converter into a store tree the game reads via
# SWOS_ASSETS. Bump seasonPack per season. That tree has no DOS extras (PC
# graphics, sound, commentary); the gaming module's openswos-data service adds
# them from the GOG PC game in ~/.swos/assets, which the wrapper prefers.
{
  lib,
  stdenv,
  stdenvNoCC,
  src,
  pkg-config,
  python3,
  SDL2,
  curl,
  cacert,
  makeWrapper,
  makeDesktopItem,
  runCommand,
}: let
  version = "0-unstable-${lib.substring 0 8 (src.lastModifiedDate or "19700101")}";

  unwrapped = stdenv.mkDerivation {
    pname = "openswos-unwrapped";
    inherit version src;

    nativeBuildInputs = [pkg-config python3];
    buildInputs = [SDL2];

    enableParallelBuilding = true;

    # The Makefile hard-codes SHELL := /bin/bash.
    makeFlags = ["X86_64=1" "SHELL=${stdenv.shell}"];

    postBuild = ''
      make -C tools/swosdata SHELL=${stdenv.shell} ''${enableParallelBuilding:+-j$NIX_BUILD_CORES}
    '';

    # The game chdir()s to its own directory and reads bin/ beside itself;
    # saves, SWOS.ini and SWOS.log go to ~/.swos.
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share $out/bin
      cp -r bin $out/share/openswos
      install -Dm755 tools/swosdata/build/swosdata $out/bin/swosdata
      for d in packaging/linux/hicolor/*/apps; do
        install -Dm644 $d/openswos.png $out/share/icons/hicolor/$(basename $(dirname $d))/apps/openswos.png
      done
      runHook postInstall
    '';
  };

  # MediaFire only hands out short-lived direct links, so read the current one
  # off the file page; the pinned hash keeps the download fixed.
  seasonPack = stdenvNoCC.mkDerivation {
    name = "SensibleWorldOfSoccer2526_v2.3.lha";
    nativeBuildInputs = [curl];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    outputHashMode = "flat";
    outputHash = "sha256-nELlssM9JWx7iOlw3P6h1dFOjwPleA0HHwAy9A3bCXs=";
    buildCommand = ''
      page=$(curl -fsSL -A Mozilla/5.0 https://www.mediafire.com/file/731btor9o5rci0h/SensibleWorldOfSoccer2526_v2.3.lha/file)
      direct=$(grep -oE 'https://download[0-9]*\.mediafire\.com/[^"]+' <<<"$page" | head -n1)
      curl -fsSL -A Mozilla/5.0 -o $out "$direct"
    '';
  };

  # Built by the same swosdata as the game, so ASSETS.ini's data versions
  # always match and the game never asks for a setup update.
  assets = runCommand "openswos-assets-2526" {} ''
    ${unwrapped}/bin/swosdata --adf ${seasonPack} --out $out --res ${unwrapped}/share/openswos
  '';

  desktopItem = makeDesktopItem {
    name = "openswos";
    desktopName = "OpenSWOS";
    comment = "Sensible World of Soccer 96/97, 25/26 season";
    exec = "openswos";
    icon = "openswos";
    categories = ["Game" "SportsGame"];
  };
in
  runCommand "openswos-${version}" {
    nativeBuildInputs = [makeWrapper];
    passthru = {inherit unwrapped assets seasonPack;};
    meta = {
      description = "Open-source C port of Sensible World of Soccer 96/97, with the 25/26 season";
      homepage = "https://github.com/benbaker76/OpenSWOS";
      license = with lib.licenses; [
        gpl3Only
        unfree # game data converted from the season pack
      ];
      mainProgram = "openswos";
      platforms = ["x86_64-linux"];
    };
  } ''
    mkdir -p $out/bin $out/share/applications
    # exec the real binary (not a symlink) so /proc/self/exe is the store dir.
    # ~/.swos/assets (built with the PC game by the gaming module's
    # openswos-data service) wins; the Amiga-only store tree is the fallback.
    # PC commentary over the Amiga sounds by default (SWOS_COMMENTARY beats
    # SWOS.ini, so change it in the environment, not the ini).
    makeWrapper ${unwrapped}/share/openswos/SWOS.x86_64 $out/bin/openswos \
      --run 'if [ -z "''${SWOS_ASSETS:-}" ] && [ ! -e "$HOME/.swos/assets/ASSETS.ini" ]; then export SWOS_ASSETS=${assets}; fi' \
      --set-default SWOS_COMMENTARY on
    ln -s ${unwrapped}/bin/swosdata $out/bin/swosdata
    ln -s ${unwrapped}/share/icons $out/share/icons
    ln -s ${desktopItem}/share/applications/openswos.desktop $out/share/applications/
  ''
