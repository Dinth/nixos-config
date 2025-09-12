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
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      programs._1password.enable = true;
#      environment.systemPackages = with pkgs; [
#      ];
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      programs._1password-gui.enable = true;
      programs._1password-gui.polkitPolicyOwners = [ "${config.primaryUser.name}" ];
    })
  ];
}
