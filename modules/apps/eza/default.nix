{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  cfg = mkIf cfg.enable {
    programs.eza = {
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
