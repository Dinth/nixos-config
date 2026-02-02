{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.lnxlink;
  primaryUsername = config.primaryUser.name;

  lnxlink = pkgs.python3Packages.buildPythonPackage rec {
    pname = "lnxlink";
    version = "2025.6.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "bkbilly";
      repo = "lnxlink";
      rev = "${version}";
      hash = "sha256-Ov3o3Ue7HEDnb58XO7dhKOpItffYxRdi8vE3EUPwgOo=";
    };

    postPatch = ''
      sed -i"" -E 's@requires = .*@requires = ["setuptools", "wheel"]@g' pyproject.toml
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
      };

      mqtt = {
        broker = mkOption {
          type = types.str;
          default = "localhost";
        };

        port = mkOption {
          type = types.port;
          default = 1883;
        };

        credentialsFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
      };

      autodiscovery = mkOption {
        type = types.bool;
        default = true;
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
        } // lib.optionalAttrs (cfg.mqtt.credentialsFile != null) {
          ExecStartPre = "${pkgs.bash}/bin/bash %h/.config/lnxlink/make-env.sh ${cfg.mqtt.credentialsFile} %h/.config/lnxlink/mqtt-env";
          EnvironmentFile = "%h/.config/lnxlink/mqtt-env";
        };

        Install.WantedBy = [ "default.target" ];
      };

      xdg.configFile."lnxlink/config.yaml".text = ''
        mqtt:
          broker: ${cfg.mqtt.broker}
          port: ${toString cfg.mqtt.port}
          ${lib.optionalString (cfg.mqtt.credentialsFile != null) "username: $MQTT_USERNAME\n          password: $MQTT_PASSWORD"}

        autodiscovery: ${lib.boolToString cfg.autodiscovery}

        modules:
          control: { shutdown: true, restart: true, suspend: true, hibernate: true, send_keys: true, notify: true, media: true, screen: true, bash: true }
          monitor: { cpu: true, ram: true, network: true, disk: true, battery: true, idle: true, media: true, microphone: true, camera: true, gpu: true, updates: true }

        logging: { level: INFO }
      '';
    };
  };
}
