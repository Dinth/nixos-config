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
        description = "Enable 1Password CLI";
      };
    };
  };
  config = mkIf cfg.enable {

  };
}
