{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;

  catppuccin_konsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.konsole = {
      enable = true;
      customColorSchemes = {
        catppuccinLatte = catppuccin_konsole + /themes/catppuccin-latte.colorscheme;
        catppuccinFrappe = catppuccin_konsole + /themes/catppuccin-frappe.colorscheme;
        catppuccinMacchiato = catppuccin_konsole + /themes/catppuccin-macchiato.colorscheme;
        catppuccinMocha = catppuccin_konsole + /themes/catppuccin-mocha.colorscheme;
      };
      defaultProfile = "Default";
      extraConfig = {
        KonsoleWindow = {
          RememberWindowSize = false;
        };
      };
      profiles.default = {
        name = "Default";
        colorScheme = "catppuccinMocha";
        font = {
          name = "FiraCode Nerd Font Med";
          size = 10;
        };
      };
    };
  };
}
