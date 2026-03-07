{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.lnxlink;
  primaryUsername = config.primaryUser.name;
  hostname = config.networking.hostName;

  lnxlink = pkgs.python3Packages.buildPythonPackage rec {
    pname = "lnxlink";
    version = "2026.2.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "bkbilly";
      repo = "lnxlink";
      rev = "${version}";
      hash = "sha256-PyonUBCeEiXQWsW9v5F3XiQE30xPOkRJTNmtaktg0Sw=";
    };

    postPatch = ''
      sed -i"" -E 's@requires = .*@requires = ["setuptools", "wheel"]@g' pyproject.toml
      sed -i"" '/asyncio/d' pyproject.toml

      # Fix log file location - use ~/.local/state/lnxlink instead of config directory
      substituteInPlace lnxlink/files_setup.py \
        --replace-fail 'config_dir = os.path.dirname(os.path.realpath(config_path))' \
                       'config_dir = os.path.expanduser("~/.local/state/lnxlink"); os.makedirs(config_dir, exist_ok=True)'
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
in
{
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

    home-manager.users.${primaryUsername} = { config, ... }: {
      systemd.user.services.lnxlink = {
        Unit = {
          Description = "LNXlink";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStartPre = "${setupScript}";
          ExecStart = "${lnxlink}/bin/lnxlink -c %h/.local/state/lnxlink/config.yaml";
          Restart = "on-failure";
          RestartSec = "10s";
          NoNewPrivileges = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        };

        Install.WantedBy = [ "default.target" ];
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
