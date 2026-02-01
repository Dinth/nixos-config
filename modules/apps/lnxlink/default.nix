{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption types getExe;
  cfg = config.lnxlink;
  primaryUsername = config.primaryUser.name;

  # Python environment with lnxlink and its dependencies
  lnxlink-python = pkgs.python3.withPackages (ps: with ps; [
    lnxlink
    paho-mqtt
  ]);
in
{
  options = {
    lnxlink = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable LNXlink - Linux companion app for Home Assistant integration via MQTT";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.python3Packages.lnxlink;
        description = "LNXlink package to use";
      };

      mqtt = {
        broker = mkOption {
          type = types.str;
          default = "localhost";
          description = "MQTT broker hostname or IP address";
          example = "10.10.1.100";
        };

        port = mkOption {
          type = types.port;
          default = 1883;
          description = "MQTT broker port";
        };

        credentialsFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to agenix secrets file containing MQTT credentials.
            File format (plain text after decryption):
            Line 1: username
            Line 2: password
          '';
          example = "config.age.secrets.lnxlink-mqtt-creds.path";
        };
      };
      autodiscovery = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Home Assistant MQTT Autodiscovery";
      };

      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to custom lnxlink configuration YAML file";
        example = "/etc/lnxlink/config.yaml";
      };
    };
  };

  config = mkIf cfg.enable {
    # System packages - install dependencies needed by lnxlink
    environment.systemPackages = with pkgs; [
      xdotool           # For sending keystrokes and window control
      xprintidle        # For idle time detection (X11)
      xdg-utils         # For URL/file opening
      pulseaudio        # For audio device enumeration
      pciutils          # For GPU detection
    ];

    home-manager.users.${primaryUsername} = { config, ... }: {
      home.packages = [
        lnxlink-python
        # Optional: packages for specific features
        pkgs.xdotool
        pkgs.xprintidle
      ];

      # Create systemd user service
      systemd.user = {
        services.lnxlink = {
          Unit = {
            Description = "LNXlink - Linux Home Assistant Companion";
            Documentation = "https://bkbilly.github.io/lnxlink/";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = "${lnxlink-python}/bin/lnxlink -c %h/.config/lnxlink/config.yaml";
            Restart = "on-failure";
            RestartSec = "10s";

            # Environment and security settings
            StandardOutput = "journal";
            StandardError = "journal";

            # Optional: Load MQTT password from agenix secret
            # EnvironmentFile = "%h/.config/lnxlink/mqtt-env";
          };

          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };

      # Create default configuration file if not using custom config
      xdg.configFile."lnxlink/config.yaml" =
        if cfg.configFile != null
        then { source = cfg.configFile; }
        else {
          text = ''
            mqtt:
              broker: ${cfg.mqtt.broker}
              port: ${toString cfg.mqtt.port}
              ${lib.optionalString (cfg.mqtt.username != "") "username: ${cfg.mqtt.username}"}
              # password: !secret mqtt_password

            # Home Assistant MQTT Discovery
            autodiscovery: ${lib.boolToString cfg.autodiscovery}

            # Modules - choose which features to enable
            modules:
              # System control
              control:
                shutdown: true
                restart: true
                suspend: true
                hibernate: true
                send_keys: true
                notify: true
                media: true
                screen: true
                bash: true

              # System monitoring
              monitor:
                cpu: true
                ram: true
                network: true
                disk: true
                battery: true
                idle: true
                media: true
                microphone: true
                camera: true
                gpu: true
                updates: true

            # Logging
            logging:
              level: INFO
          '';
        };

      # Optional: Create environment file for MQTT credentials
      # This is useful when using agenix secrets
      xdg.configFile."lnxlink/mqtt-env" = {
        text = "MQTT_PASSWORD=${builtins.getEnv "LNXLINK_MQTT_PASSWORD"}";
      };
    };

    # Helper option: Enable KDE-specific features if KDE is enabled
    systemd.user.services.lnxlink.Unit.After =
      lib.optional config.kde.enable "plasmawayland-session.target";
  };
}
