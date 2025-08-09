{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config._1password;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    _1password = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 1Password CLI";
      };
      gui = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 1Password GUI";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      programs._1password.enable = true;
      services.pcscd.enable = true;
      environment.systemPackages = with pkgs; [
        libfido2 # FIDO2 library (for Yubikeys)
        yubikey-manager # Yubikey manager
      ];
    })
    (mkIf (cfg.enable && cfg.gui) {
      programs._1password-gui.enable = true;
      programs._1password-gui.polkitPolicyOwners = [ "${config.primaryUser.name}" ];
      environment.systemPackages = with pkgs; [
        yubioath-flutter
      ];
    })
  ];
}
