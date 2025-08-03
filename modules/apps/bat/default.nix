{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.bat = {
      enable = true;
      config = {
        map-syntax = ".ignore:Git Ignore";
        style = "numbers,changes";
      };
    };
#    catppuccin.bat = mkIf cfg.catppuccin {
#      enable = true;
#    };
  };
}
