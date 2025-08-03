{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.gaming;
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
  imports = [
    ../apps/steam
  ];
  programs.gamemode.enable = true;
}
