{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  config = mkIf cfg.enable {
    programs.btop = {
      enable = true;
      settings = {
#        color_theme = "catppuccin_macchiato";
        truecolor = "True";
      };
    };
  };
}
