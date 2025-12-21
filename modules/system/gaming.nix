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
  config = mkIf cfg.enable {
    programs.gamemode.enable = true;
    environment.systemPackages = [
      pkgs.lutris
      pkgs.openttd-jgrpp
      pkgs.heroic
    ];
  };
}
