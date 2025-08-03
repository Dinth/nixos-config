{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.1password;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    1password = {
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
  config = mkIf cfg.enable {

  };
}
