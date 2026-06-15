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
      # Installs the catppuccin .tmTheme AND points programs.bat.config.theme at
      # it, using the global catppuccin.flavor (from theme.flavor). Previously a
      # BAT_THEME="Catppuccin Mocha" env var was set without ever installing the
      # theme, so bat warned "unknown theme" and silently fell back to default.
      catppuccin.bat.enable = true;
      programs.bat = {
        enable = true;
        config = {
          map-syntax = ".ignore:Git Ignore";
          style = "numbers,changes";
        };
      };
    };
  };
}
