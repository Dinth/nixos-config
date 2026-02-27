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

      # Skip writing config if read-only (NixOS symlinks to nix store)
      substituteInPlace lnxlink/config_setup.py \
        --replace-fail 'if len(missing_keys) > 0:' \
                       'if len(missing_keys) > 0 and os.access(config_path, os.W_OK):'
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
        broker = mkOption {
          type = types.str;
          default = "localhost";
          description = "MQTT broker hostname or IP address.";
        };

        port = mkOption {
          type = types.port;
          default = 1883;
          description = "MQTT broker port.";
        };

        credentialsFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to file containing MQTT username (line 1) and password (line 2).";
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
#      lnxlink
      xdotool
      xprintidle
      xdg-utils
      pulseaudio
      pciutils
    ];

    home-manager.users.${primaryUsername} = { config, ... }: {

      home.file.".config/lnxlink/make-env.sh" = mkIf (cfg.mqtt.credentialsFile != null) {
        text = ''
          #!/usr/bin/env bash
          if [ -f "$1" ]; then
            echo "MQTT_USERNAME=$(sed -n '1p' "$1")" > "$2"
            echo "MQTT_PASSWORD=$(sed -n '2p' "$1")" >> "$2"
            chmod 600 "$2"
          fi
        '';
        executable = true;
      };

      systemd.user.services.lnxlink = {
        Unit = {
          Description = "LNXlink";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${lnxlink}/bin/lnxlink -c %h/.config/lnxlink/config.yaml";
          Restart = "on-failure";
          RestartSec = "10s";
          # Light hardening (lnxlink needs broad access for monitoring/control)
          NoNewPrivileges = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        } // lib.optionalAttrs (cfg.mqtt.credentialsFile != null) {
          ExecStartPre = "${pkgs.bash}/bin/bash %h/.config/lnxlink/make-env.sh ${cfg.mqtt.credentialsFile} %h/.config/lnxlink/mqtt-env";
          EnvironmentFile = "%h/.config/lnxlink/mqtt-env";
        };

        Install.WantedBy = [ "default.target" ];
      };

      xdg.configFile."lnxlink/config.yaml".text = ''
        mqtt:
          prefix: lnxlink
          clientId: ${hostname}
          server: ${cfg.mqtt.broker}
          port: ${toString cfg.mqtt.port}
          auth:
            user: ${if cfg.mqtt.credentialsFile != null then "$MQTT_USERNAME" else ""}
            pass: ${if cfg.mqtt.credentialsFile != null then "$MQTT_PASSWORD" else ""}
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
