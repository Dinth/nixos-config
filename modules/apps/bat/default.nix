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
    environment.variables = {
      # Make bat use the theme if enabled
      BAT_THEME = "Catppuccin Mocha";
    };
  };
}
