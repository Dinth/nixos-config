{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.kate = {
      enable = true;
      editor = {
        font = {
          family = "FiraCode Nerd Font Med";
          pointSize = 10;
        };
        indent = {
          replaceWithSpaces = true;
          width = 2;
        };
        tabWidth = 2;
      };
    };
  };
}
