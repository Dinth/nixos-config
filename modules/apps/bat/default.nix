{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  cfg = mkIf cfg.enable {
    programs.bat = {
      enable = true;
      config = {
        map-syntax = ".ignore:Git Ignore";
        style = "numbers,changes";
      };
    };
    catppuccin.bat = mkIf cfg.catppuccin {
      enable = true;
    };
  };
}
