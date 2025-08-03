{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.virtualisation;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    virtualisation = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable virtualisation.";
      };
    };
  };

}
