{
  config,
  lib,
  isDarwin,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.theme;
  primaryUsername = config.primaryUser.name;

  # macOS only has eight fixed accent colours; map the Catppuccin accent
  # (catppuccin.accent, default mauve) to the nearest one. Values are what
  # System Settings itself writes for AppleAccentColor/AppleHighlightColor.
  macAccents = {
    red = [0 "1.000000 0.733333 0.721569 Red"];
    orange = [1 "1.000000 0.874510 0.701961 Orange"];
    yellow = [2 "1.000000 0.937255 0.690196 Yellow"];
    green = [3 "0.752941 0.964706 0.678431 Green"];
    blue = [4 "0.698039 0.843137 1.000000 Blue"];
    purple = [5 "0.968627 0.831373 1.000000 Purple"];
    pink = [6 "1.000000 0.749020 0.823529 Pink"];
  };
  catppuccinToMac = {
    rosewater = "pink";
    flamingo = "pink";
    pink = "pink";
    mauve = "purple";
    lavender = "purple";
    red = "red";
    maroon = "red";
    peach = "orange";
    yellow = "yellow";
    green = "green";
    teal = "green";
    sky = "blue";
    sapphire = "blue";
    blue = "blue";
  };
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
    # macOS accent + text-highlight colour from the Catppuccin accent.
    (lib.optionalAttrs isDarwin (let
      mac = macAccents.${catppuccinToMac.${config.home-manager.users.${primaryUsername}.catppuccin.accent}};
    in {
      system.defaults.CustomUserPreferences.NSGlobalDomain = {
        AppleAccentColor = builtins.elemAt mac 0;
        AppleHighlightColor = builtins.elemAt mac 1;
      };
    }))

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
