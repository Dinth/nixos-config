{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.btop = {
      enable = true;
      settings = {
#        color_theme = "catppuccin_macchiato";
        truecolor = "True";
      };
    };
  };
}
