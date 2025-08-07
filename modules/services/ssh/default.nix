{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.ssh;
in
{
  options = {
    ssh = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SSH server";
      };
    };
  };
  config = mkIf cfg.enable {
    services.openssh = {
      enable = lib.mkDefault false; # Disabled by default, enable per host
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
      };
    };
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "10m";
    };
  };
  };
}
