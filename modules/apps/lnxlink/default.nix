{
  config,
  pkgs,
  lib,
  lnxlink,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.lnxlink;
  primaryUsername = config.primaryUser.name;
  hostname = config.networking.hostName;

  # dbus-mediaplayer: runtime dependency of lnxlink's `media` (MPRIS) module.
  # Not in nixpkgs and lnxlink would otherwise try to `pip install` it at
  # runtime, which fails on the read-only Nix store — so the module crashes
  # with "'NoneType' object has no attribute 'DBusMediaPlayers'". Package it
  # here so the import succeeds and MPRIS works.
  dbusMediaplayer = pkgs.python3Packages.buildPythonPackage rec {
    pname = "dbus-mediaplayer";
    version = "2025.6.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "dbus_mediaplayer";
      inherit version;
      sha256 = "1i7g1bldjfqa8ghhq56s86ljy70h8yfph0ymnjkkxmcy970038g6";
    };

    # Upstream pins exact build deps (setuptools~=69.2.0, wheel~=0.43.0) that
    # nixpkgs doesn't ship; relax them like the lnxlink derivation does.
    postPatch = ''
      sed -i"" -E 's@requires = .*@requires = ["setuptools", "wheel"]@g' pyproject.toml
    '';

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
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

  # lnxlink source pinned via flake input — bump with
  # `nix flake update lnxlink`. The narHash recorded in flake.lock
  # supersedes the previous inline fetchFromGitHub hash and the
  # version-string-as-tag.
  lnxlinkPkg = pkgs.python3Packages.buildPythonPackage {
    pname = "lnxlink";
    version = lnxlink.shortRev or "dev";
    pyproject = true;

    src = lnxlink;

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

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      paho-mqtt
      pyyaml
      requests
      dbus-python
      pygobject3
      pydbus
      pygobject3
      dasbus
      psutil
      distro
      inotify
      beaupy
      aiohttp
      jeepney
      dbusMediaplayer
    ];

    meta = with lib; {
      description = "Linux companion app for Home Assistant";
      homepage = "https://github.com/bkbilly/lnxlink";
      license = licenses.mit;
    };
  };

  # Script to prepare runtime config from template + secrets
  setupScript = pkgs.writeShellScript "lnxlink-setup" ''
    set -euo pipefail
    RUNTIME_DIR="$HOME/.local/state/lnxlink"
    TEMPLATE="$HOME/.config/lnxlink/config.yaml.template"
    CONFIG="$RUNTIME_DIR/config.yaml"
    SECRETS="${cfg.mqtt.secretsFile}"

    mkdir -p "$RUNTIME_DIR"

    if [ -f "$SECRETS" ]; then
      MQTT_SERVER=$(sed -n '1p' "$SECRETS")
      MQTT_USER=$(sed -n '2p' "$SECRETS")
      MQTT_PASS=$(sed -n '3p' "$SECRETS")
    else
      echo "Secrets file not found: $SECRETS" >&2
      exit 1
    fi

    sed -e "s|__MQTT_SERVER__|$MQTT_SERVER|g" \
        -e "s|__MQTT_USER__|$MQTT_USER|g" \
        -e "s|__MQTT_PASS__|$MQTT_PASS|g" \
        "$TEMPLATE" > "$CONFIG"
    chmod 600 "$CONFIG"
  '';
in {
  options = {
    lnxlink = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable LNXLink Home Assistant companion service.";
      };

      mqtt = {
        secretsFile = mkOption {
          type = types.path;
          description = "Path to file containing: MQTT server (line 1), username (line 2), password (line 3).";
        };

        port = mkOption {
          type = types.port;
          default = 1883;
          description = "MQTT broker port.";
        };
      };

      autodiscovery = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Home Assistant MQTT autodiscovery.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xdotool
      xprintidle
      xdg-utils
      pulseaudio
      pciutils
    ];

    home-manager.users.${primaryUsername} = {config, ...}: {
      systemd.user.services.lnxlink = {
        Unit = {
          Description = "LNXlink";
          After = ["network-online.target"];
          Wants = ["network-online.target"];
        };

        Service = {
          Type = "simple";
          ExecStartPre = "${setupScript}";
          ExecStart = "${lnxlinkPkg}/bin/lnxlink -c %h/.local/state/lnxlink/config.yaml -e beacondb";
          Restart = "on-failure";
          RestartSec = "10s";
          NoNewPrivileges = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        };

        Install.WantedBy = ["default.target"];
      };

      xdg.configFile."lnxlink/config.yaml.template".text = ''
        mqtt:
          prefix: lnxlink
          clientId: ${hostname}
          server: __MQTT_SERVER__
          port: ${toString cfg.mqtt.port}
          auth:
            user: __MQTT_USER__
            pass: __MQTT_PASS__
            tls: false
            keyfile: ""
            certfile: ""
            ca_certs: ""
          discovery:
            enabled: ${lib.boolToString cfg.autodiscovery}
            prefix: homeassistant
          lwt:
            enabled: true
            qos: 1
          clear_on_off: false
        update_interval: 5
        update_on_change: true
        modules:
        custom_modules:
        exclude:
        settings:
          statistics: ""
        logging:
          level: INFO
      '';
    };
  };
}
