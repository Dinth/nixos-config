{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.ghostty;
  primaryUsername = config.primaryUser.name;
in {
  options.ghostty.enable = mkOption {
    type = lib.types.bool;
    # The Linux desktops use Konsole (modules/apps/konsole); Ghostty is the
    # Mac's terminal.
    default = isDarwin && config.graphical.enable;
    defaultText = lib.literalExpression "isDarwin && config.graphical.enable";
    description = "Ghostty terminal with the shared Catppuccin theme and Fira Code font.";
  };

  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      # Follows the global catppuccin.flavor set from theme.flavor.
      catppuccin.ghostty.enable = true;

      programs.ghostty = {
        enable = true;
        # nixpkgs' `ghostty` builds from source for Linux only; on macOS
        # `ghostty-bin` repackages the signed upstream app (Home Manager then
        # copies Ghostty.app into ~/Applications/Home Manager Apps).
        package =
          if isDarwin
          then pkgs.ghostty-bin
          else pkgs.ghostty;
        enableZshIntegration = true;
        settings = {
          # Installed system-wide by graphical.nix (nerd-fonts.fira-code).
          font-family = "FiraCode Nerd Font Mono";
          font-size = 14;
          window-padding-x = 8;
          window-padding-y = 8;
          window-save-state = "always";
          # Left Option acts as Alt/Meta for zsh and mc key bindings; the
          # right one still types Polish diacritics (ą, ę, ś...) on the
          # Polish layouts.
          macos-option-as-alt = "left";
        };
      };
    };
  };
}
