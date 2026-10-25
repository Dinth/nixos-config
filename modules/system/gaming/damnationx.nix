# DamnationX — DevilutionX fork with HD 2D art, a 3D renderer, an online
# lobby and Diablo II sound/art imports. Saves, MPQs and diablo.ini live in
# the same SDL pref dir as DevilutionX (~/.local/share/diasurgical/devilution);
# launcher settings go to ~/.config/damnationx/launcher.
#
# The 3D renderer (Toxoid) is closed source and ships only in the prebuilt
# Ubuntu release, whose licence forbids modifying it. So the binaries are
# installed untouched (no patchelf) and run inside an FHS env. Bump version +
# hash per release.
{
  lib,
  pkgs,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
  makeDesktopItem,
}: let
  version = "1.6.0-beta.8.2";

  # Provided by the FHS env. The wrapper scripts put the release's bundled
  # Ubuntu 24.04 libs/ first on LD_LIBRARY_PATH, and those shadow what the
  # system's Mesa Vulkan drivers need (old libwayland-client: "undefined
  # symbol: wl_fixes_interface", so no GPU). Any bundled lib one of these
  # ships is dropped from libs/; game-specific ones (Smacker, SDL_audiolib,
  # its SDL2) stay, as does libbz2: Debian names it libbz2.so.1.0, which
  # nixpkgs bzip2 ships but ldconfig does not index (its soname is .so.1).
  systemLibs = with pkgs; [
    alsa-lib
    dbus
    expat
    flac
    lame
    libapparmor
    libasyncns
    libbsd
    libcap
    libdecor
    libdrm
    libffi
    libgbm
    libgcrypt
    libgpg-error
    libmd
    libogg
    libpng
    libpulseaudio
    libsamplerate
    libsndfile
    libsodium
    libvorbis
    libx11
    libxau
    libxcb
    libxcursor
    libxdmcp
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    lz4
    mpg123
    opus
    stdenv.cc.cc.lib
    systemd
    wayland
    xz
    zlib
    zstd
  ];

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "damnationx-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://github.com/trygentic/damnationx/releases/download/v${version}/damnationx-game-and-launcher-${version}-linux-x64.tar.gz";
      hash = "sha256-owMNO/7wGwgjUine36cn8sggSfNID9w9yM/oyMSVsLE=";
    };

    # Leave the binaries exactly as shipped.
    dontFixup = true;

    installPhase = ''
      mkdir -p $out/share/damnationx
      cp -r . $out/share/damnationx/
      for lib in $out/share/damnationx/libs/*; do
        for dir in ${lib.concatMapStringsSep " " (p: "${lib.getLib p}/lib") systemLibs}; do
          if [ -e "$dir/$(basename "$lib")" ]; then
            rm "$lib"
            break
          fi
        done
      done
    '';
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/trygentic/damnationx/facdcba3d1dd6dd08d814084afb94e44369b2c57/android-project/app/src/main/ic_launcher-playstore.png";
    hash = "sha256-n2QR23Bl2RNxRUR+SiA2KmxX0hTBR27cTD6az/dxSiM=";
  };

  # The launcher saves the game and importer paths it discovers next to
  # itself. A store path there would keep launching the old release after a
  # bump (and break once it is GC'd), so the release is bind-mounted at a
  # stable /opt/damnationx, and paths saved by earlier store-path launches are
  # rewritten to it. "Match display" (auto_resolution) is forced on too; the
  # file only exists after the launcher's first run.
  launch = pkgs.writeShellScript "damnationx-launch" ''
    settings="''${XDG_CONFIG_HOME:-$HOME/.config}/damnationx/launcher/settings.json"
    if [ -f "$settings" ]; then
      sed -i -E 's#/nix/store/[a-z0-9]+-damnationx-unwrapped-[^/]+/share/damnationx#/opt/damnationx#g' "$settings"
      tmp=$(mktemp "$settings.XXXXXX")
      ${lib.getExe pkgs.jq} '.auto_resolution = true' "$settings" >"$tmp" && mv "$tmp" "$settings"
    fi
    exec /opt/damnationx/launcher "$@"
  '';

  desktopItem = makeDesktopItem {
    name = "damnationx";
    desktopName = "DamnationX";
    comment = "Diablo with HD art, a 3D renderer and an online lobby";
    exec = "damnationx";
    icon = "damnationx";
    categories = ["Game" "RolePlaying"];
  };
in
  buildFHSEnv {
    pname = "damnationx";
    inherit version;

    # GPU stack plus systemLibs from the system. Python is for the launcher's
    # optional D2R importer, which builds a venv and pip-installs
    # NumPy/Pillow wheels.
    targetPkgs = pkgs:
      map lib.getLib systemLibs
      ++ (with pkgs; [
        vulkan-loader
        libGL
        xkeyboard-config # /usr/share/X11/xkb, or winit panics on Wayland
        python3
      ]);

    extraBwrapArgs = ["--ro-bind ${unwrapped}/share/damnationx /opt/damnationx"];
    runScript = launch;

    extraInstallCommands = ''
      install -Dm644 ${desktopItem}/share/applications/damnationx.desktop \
        $out/share/applications/damnationx.desktop
      install -Dm644 ${icon} $out/share/icons/hicolor/512x512/apps/damnationx.png
    '';

    meta = {
      description = "DevilutionX-based Diablo port with HD art, a 3D renderer and an online lobby";
      homepage = "https://github.com/trygentic/damnationx";
      license = lib.licenses.unfree; # Sustainable Use License + proprietary Toxoid
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "damnationx";
      platforms = ["x86_64-linux"];
    };
  }
