{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.yubikey;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    yubikey = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable support for Yubikeys";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      services.pcscd.enable = true;
      # Enforcing yubikey-manager 5.7.1 - required for yubioath-flutter <=7.2.3
      environment.systemPackages = [
        pkgs.libfido2
        yubikey-manager
      ];
#      environment.systemPackages = with pkgs; [
#        libfido2 # FIDO2 library (for Yubikeys)
#        yubikey-manager # Yubikey manager
#      ];
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      environment.systemPackages = with pkgs; [
        yubioath-flutter
      ];
    })
  ];
}
