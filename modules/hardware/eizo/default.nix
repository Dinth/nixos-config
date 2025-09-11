{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.eizo;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    eizo = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable support for Eizo screen (DDC)";
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernelModules = ["i2c-dev"];
    environment.systemPackages = with pkgs; [
      ddcutil
      ddccontrol
    ];
#     services.udev.extraRules = ''
#           KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
#     '';
    hardware.i2c.enable = true;
  };
}
