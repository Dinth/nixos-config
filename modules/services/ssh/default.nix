{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.ssh;
in {
  options = {
    ssh = {
      enable = mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH server";
      };
    };
  };
  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
        MaxAuthTries = 3;
        LoginGraceTime = 30;
        AllowUsers = [config.primaryUser.name];
      };
    };
    services.fail2ban = {
      enable = true;
      # Raised from 3 → 5: a flapping key (e.g. YubiKey replug, agent
      # restart) easily burns 3 retries from a trusted device.
      maxretry = 5;
      bantime = "10m";
      bantime-increment = {
        enable = true;
        maxtime = "48h";
      };
      # Don't lock ourselves out over the LAN / tailnet.
      ignoreIP = [
        "127.0.0.0/8"
        "10.10.0.0/16"
        "100.64.0.0/10"
      ];
    };
  };
}
