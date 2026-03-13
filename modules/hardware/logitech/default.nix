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
      logiops
    ];
    systemd.services.logiops = {
      description = "An unofficial userspace driver for HID++ Logitech devices";
      wantedBy = [ "graphical.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.logiops}";
        Restart = "on-failure";
        RestartSec = "3";
      };
      restartTriggers = [ config.environment.etc."logid.cfg".source ];
    };
    environment.etc."logid.cfg".source = ./logid.cfg;

    # Restart logiops when Logitech USB receiver connects
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", TAG+="systemd", ENV{SYSTEMD_WANTS}="logiops.service"
    '';

    # Mouse-specific libinput settings
    services.libinput.mouse = {
      accelProfile = "flat";
      accelSpeed = "0";
    };
  };
}

