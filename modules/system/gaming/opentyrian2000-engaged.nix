# OpenTyrian2000 Engaged — fork of KScl/opentyrian2000 (widescreen, Endless
# mode, online co-op, ship/weapon editors). Not in nixpkgs; based on the
# opentyrian2000 derivation from nixpkgs PR #567565.
#
# MIDI (FluidSynth) is Windows-only upstream, so this build uses the default
# OPL3 synth.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchzip,
  SDL2,
  SDL2_net,
  pkg-config,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "opentyrian2000-engaged";
  version = "1.4.2";

  src = fetchFromGitHub {
    owner = "wlfn1116";
    repo = "OpenTyrian2000-Engaged";
    tag = finalAttrs.version;
    hash = "sha256-ALpOqfh+MBMFp9u4h26ZOK5NrCzHTRhZDHdskqIWqrs=";
  };

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
    "VCS_IDREV=echo ${finalAttrs.version}"
  ];

  # Upstream renamed README to README.md but the install target still wants README.
  postPatch = ''
    substituteInPlace Makefile --replace-fail "NEWS README " "NEWS README.md "
  '';

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
})
