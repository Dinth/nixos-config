# lnxlink packaging — called via the lnxlinkOverlay in flake.nix as
# `pkgs.lnxlink`, with `src` set to the non-flake `lnxlink` input
# (bump with `nix flake update lnxlink`). Kept out of the NixOS module
# so the package is a plain callPackage-able derivation.
{
  lib,
  python3Packages,
  fetchPypi,
  src,
}: let
  # dbus-mediaplayer: runtime dependency of lnxlink's `media` (MPRIS) module.
  # Not in nixpkgs and lnxlink would otherwise try to `pip install` it at
  # runtime, which fails on the read-only Nix store — so the module crashes
  # with "'NoneType' object has no attribute 'DBusMediaPlayers'". Package it
  # here so the import succeeds and MPRIS works.
  dbus-mediaplayer = python3Packages.buildPythonPackage rec {
    pname = "dbus-mediaplayer";
    version = "2025.6.0";
    pyproject = true;

    src = fetchPypi {
      pname = "dbus_mediaplayer";
      inherit version;
      sha256 = "1i7g1bldjfqa8ghhq56s86ljy70h8yfph0ymnjkkxmcy970038g6";
    };

    # Upstream pins exact build deps (setuptools~=69.2.0, wheel~=0.43.0) that
    # nixpkgs doesn't ship; relax them like the lnxlink derivation does.
    postPatch = ''
      sed -i"" -E 's@requires = .*@requires = ["setuptools", "wheel"]@g' pyproject.toml
    '';

    nativeBuildInputs = with python3Packages; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with python3Packages; [
      jeepney
    ];

    # No test suite shipped in the sdist.
    doCheck = false;
    pythonImportsCheck = ["dbus_mediaplayer"];

    meta = with lib; {
      description = "Currently playing media using DBus";
      homepage = "https://github.com/bkbilly/dbus_mediaplayer";
      license = licenses.mit;
    };
  };
in
  python3Packages.buildPythonPackage {
    pname = "lnxlink";
    version = src.shortRev or "dev";
    pyproject = true;

    inherit src;

    postPatch = ''
            sed -i"" -E 's@requires = .*@requires = ["setuptools", "wheel"]@g' pyproject.toml
            sed -i"" '/asyncio/d' pyproject.toml

            # NOTE: no log-location patch needed — upstream's setup_logger()
            # defaults the log dir to the config file's directory, and our
            # runtime config already lives in ~/.local/state/lnxlink (see
            # setupScript + ExecStart -c path), so lnxlink.log lands there.

            # Replace GNOME-specific keep_alive with systemd-inhibit version (works on KDE)
            cat > lnxlink/modules/keep_alive.py << 'EOF'
      """Prevent system sleep using systemd-inhibit (works on KDE, GNOME, etc.)"""
      import subprocess
      from shutil import which

      class Addon:
          def __init__(self, lnxlink):
              self.name = "Keep Alive"
              self.inhibit_proc = None
              if which("systemd-inhibit") is None:
                  raise SystemError("systemd-inhibit not found")

          def exposed_controls(self):
              return {"Keep Alive": {"type": "switch", "icon": "mdi:sleep-off"}}

          def get_info(self):
              if self.inhibit_proc and self.inhibit_proc.poll() is None:
                  return True
              return False

          def start_control(self, topic, data):
              if data.lower() == "off" and self.inhibit_proc:
                  self.inhibit_proc.terminate()
                  self.inhibit_proc = None
              elif data.lower() == "on" and not self.get_info():
                  self.inhibit_proc = subprocess.Popen(
                      ["systemd-inhibit", "--what=idle:sleep", "--who=LNXlink",
                       "--why=Keep Alive", "--mode=block", "sleep", "infinity"],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
      EOF
    '';

    nativeBuildInputs = with python3Packages; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with python3Packages;
      [
        paho-mqtt
        pyyaml
        requests
        dbus-python
        pygobject3
        pydbus
        dasbus
        psutil
        distro
        inotify
        beaupy
        aiohttp
        jeepney
      ]
      ++ [dbus-mediaplayer];

    meta = with lib; {
      description = "Linux companion app for Home Assistant";
      homepage = "https://github.com/bkbilly/lnxlink";
      license = licenses.mit;
      mainProgram = "lnxlink";
    };
  }
