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
      # Shell integration off: it defines ls/ll/la/lla/lt (and an `eza` alias
      # carrying icons/extraOptions) in ~/.zshrc, which runs after /etc/zshrc
      # and so overrode the aliases in modules/system/cli.nix — `ls` was plain
      # `eza`, never the intended long listing. The whole alias set, those
      # flags included, now lives in cli.nix; this module only installs eza
      # and its catppuccin theme.
      programs.eza = {
        enable = true;
        enableZshIntegration = false;
      };
    };
  };
}
