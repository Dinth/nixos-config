{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.logitech;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    logitech = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Logitech peripherals support.";
      };
    };
  };
  config = mkIf cfg.enable {
    hardware.logitech = {
      wireless.enable = true;
      wireless.enableGraphical = true;
    };
    environment.systemPackages = with pkgs; [
      logiops # Unofficial HID driver for Logitech devices
    ];
    systemd.services.logiops = {
      description = "An unofficial userspace driver for HID++ Logitech devices";
      wantedBy = [ "graphical.target" ];
      after = [ "bluetooth.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.logiops}";
      };
      restartTriggers = [ config.environment.etc."logid.cfg".source ];
    };
    environment.etc."logid.cfg".source = ./logid.cfg;
  };
}

