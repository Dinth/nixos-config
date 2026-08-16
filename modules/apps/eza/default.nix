{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      # programs.eza.theme is an attrset that home-manager serialises straight
      # into eza/theme.yml. Setting it to the string "catppuccin.yml" produced a
      # 19-byte file whose entire content was that scalar, which eza ignores —
      # no theme was ever applied. The catppuccin module installs the real one,
      # same as catppuccin.bat/catppuccin.fzf elsewhere in the tree. It writes
      # the same eza/theme.yml, so programs.eza.theme must stay unset or the two
      # definitions collide.
      catppuccin.eza = {
        enable = true;
        accent = "mauve";
      };
      programs.eza = {
        enable = true;
        enableZshIntegration = true;
        icons = "auto";
        extraOptions = [
          "--classify"
          "--group-directories-first"
          "--header"
          "--mounts"
          "--smart-group"
        ];
      };
    };
  };
}
