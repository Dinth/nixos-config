{
  config,
  lib,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.theme;
  primaryUsername = config.primaryUser.name;
in {
  options = {
    theme = {
      flavor = mkOption {
        type = types.enum ["latte" "frappe" "macchiato" "mocha"];
        default = "mocha";
        description = "Catppuccin flavor to use across the system.";
      };
    };
  };

  config = lib.mkMerge [
    # Home Manager catppuccin
    {home-manager.users.${primaryUsername}.catppuccin.flavor = cfg.flavor;}

    # System-level catppuccin (plymouth, etc.) — the catppuccin NixOS module
    # has no nix-darwin counterpart.
    (lib.optionalAttrs (!isDarwin) {
      catppuccin.plymouth = mkIf config.graphical.enable {
        enable = true;
        inherit (cfg) flavor;
      };
      # Linux console (TTY) palette.
      catppuccin.tty = {
        enable = true;
        inherit (cfg) flavor;
      };
      # Apps only present on the Linux desktops (Anki via kde, fcitx5 via
      # inputMethod); they follow the global flavor.
      home-manager.users.${primaryUsername}.catppuccin = {
        anki.enable = config.kde.enable or false;
        fcitx5.enable = config.inputMethod.enable or false;
      };
    })
  ];
}
