{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.eza = {
        enable = true;
        enableZshIntegration = true;
        icons = "auto";
        theme = "catppuccin.yml";
        extraOptions = [
          "--classify"
          "--group-directories-first"
          "--header"
          "--mounts"
          "--smart-group"
      ];
    };
  };
}
