{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    gaming = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gaming features.";
      };
    };
  };
#  programs.gamemode.enable = true;
}
