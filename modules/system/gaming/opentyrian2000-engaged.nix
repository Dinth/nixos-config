# OpenTyrian2000 Engaged — fork of KScl/opentyrian2000 (widescreen, Endless
# mode, online co-op, ship/weapon editors). Not in nixpkgs; based on the
# opentyrian2000 derivation from nixpkgs PR #567565. Exposed as
# `pkgs.opentyrian2000-engaged` by gamesOverlay in flake.nix, with `src` set
# to the non-flake input tracking upstream's `latest` release tag.
#
# MIDI (FluidSynth) is Windows-only upstream, so this build uses the default
# OPL3 synth.
{
  lib,
  stdenv,
  src,
  fetchzip,
  SDL2,
  SDL2_net,
  pkg-config,
}:
stdenv.mkDerivation {
  pname = "opentyrian2000-engaged";
  # The input only carries the commit, not the release tag name.
  version = "0-unstable-${lib.substring 0 8 (src.lastModifiedDate or "19700101")}";
  inherit src;

  # Freeware Tyrian 2000 data released by Jason Emery.
  data = fetchzip {
    url = "https://www.camanis.net/tyrian/tyrian2000.zip";
    hash = "sha256-KiYFsbiHtqQCJpXzKL5jyFS+Ho25unqaLGES8+Yj1Nw=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [
    SDL2
    SDL2_net
  ];

  __structuredAttrs = true;
  strictDeps = true;
  enableParallelBuilding = true;

  makeFlags = [
    "prefix=${placeholder "out"}"
    # The Makefile shells out to git for the version string.
    "VCS_IDREV=echo ${src.shortRev or "dev"}"
  ];

  # Makefile compiles TYRIAN_DIR = $(gamesdir)/opentyrian2000 into the binary.
  postInstall = ''
    mkdir -p $out/share/games/opentyrian2000
    cp -r $data/* $out/share/games/opentyrian2000/
  '';

  meta = {
    description = "OpenTyrian2000 fork with widescreen, Endless mode and online play";
    homepage = "https://github.com/wlfn1116/OpenTyrian2000-Engaged";
    mainProgram = "opentyrian2000";
    license = with lib.licenses; [
      gpl2Plus
      unfree # freeware data assets
    ];
    platforms = lib.platforms.linux;
  };
}
