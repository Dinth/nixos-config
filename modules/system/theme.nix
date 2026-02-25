{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.theme;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    theme = {
      flavor = mkOption {
        type = types.enum [ "latte" "frappe" "macchiato" "mocha" ];
        default = "mocha";
        description = "Catppuccin flavor to use across the system.";
      };
    };
  };

  config = {
    # System-level catppuccin (plymouth, etc.)
    catppuccin.plymouth = mkIf config.graphical.enable {
      enable = true;
      flavor = cfg.flavor;
    };

    # Home Manager catppuccin
    home-manager.users.${primaryUsername}.catppuccin.flavor = cfg.flavor;
  };
}
