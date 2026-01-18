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
}
