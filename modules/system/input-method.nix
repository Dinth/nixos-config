{
  config,
  lib,
  pkgs,
  machineType ? "",
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.inputMethod;
  primaryUsername = config.primaryUser.name;

  # Japanese deliberately has no entry in dictionaries.nix: hunspell tokenises
  # on whitespace and applies affix rules to whole words, which is meaningless
  # for a script with no word delimiters. There is no ja hunspell/nuspell
  # dictionary in nixpkgs, upstream, or Chrome's bdic set for exactly that
  # reason. Typing Japanese is an input-method problem instead.
  #
  # mozc is the open-source half of Google Japanese Input. The -ut build is the
  # same engine with the UT dictionaries merged in — jawiki titles, place and
  # personal names, neologisms — which is the same trade dictionaries.nix makes
  # by taking the SCOWL -large wordlists over the defaults: a much wider
  # conversion candidate pool for the cost of a fatter dictionary.
  mozc = pkgs.fcitx5-mozc-ut;

  # KWin spawns the input method from this desktop file, so it has to come from
  # the addon-wrapped fcitx5 rather than pkgs.fcitx5 — the wrapper rewrites
  # Exec= to its own bin/fcitx5, which is the only one that can see mozc.
  # i18n.inputMethod.package is that wrapper.
  fcitx5Desktop = "${config.i18n.inputMethod.package}/share/applications/org.fcitx.Fcitx5.desktop";
in {
  options = {
    inputMethod = {
      enable = mkOption {
        type = lib.types.bool;
        # Desktop only. KWin allows exactly one input method, claimed via
        # kwinrc [Wayland] InputMethod, and on the tablet maliit-keyboard
        # (kde.nix) wants that same slot for the on-screen keyboard. Losing the
        # OSK on a detachable is a worse trade than not having Japanese there.
        default = config.graphical.enable && machineType == "desktop";
        description = "Enable the fcitx5 input method with Japanese (mozc) support.";
      };
    };
  };

  config = mkIf cfg.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = [mozc pkgs.catppuccin-fcitx5];

        # Speak text-input-v3 to KWin rather than exporting GTK_IM_MODULE /
        # QT_IM_MODULE. Those are the X11-era toolkit hooks and never reach
        # Wayland-native clients; Chrome already carries --enable-wayland-ime
        # (modules/apps/google-chrome) for this path. XMODIFIERS=@im=fcitx is
        # still set by the upstream module, so XWayland keeps working.
        waylandFrontend = true;

        settings = {
          # Seeds /etc/xdg/fcitx5/profile. fcitx5 reads ~/.config/fcitx5 first,
          # so this is a default rather than a lock — the config tool and the
          # learned user dictionary both keep working.
          #
          # DefaultIM is keyboard-pl, not mozc, on purpose: text fields should
          # open in the Polish layout locale.nix and kde.nix already set, with
          # Ctrl+Space toggling into Japanese on demand.
          inputMethod = {
            GroupOrder."0" = "Default";
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = "pl";
              DefaultIM = "keyboard-pl";
            };
            "Groups/0/Items/0".Name = "keyboard-pl";
            "Groups/0/Items/1".Name = "mozc";
          };

          # The candidate window is the one piece of fcitx5 UI that shows up
          # over other apps, so keep it on the same catppuccin flavour as
          # everything else rather than letting it default to stock grey.
          addons.classicui.globalSection.Theme = "catppuccin-${config.theme.flavor}-mauve";
        };
      };
    };

    # plasma-manager runs with overrideConfig = true, which resets kwinrc on
    # every activation — so picking Fcitx 5 in the Virtual Keyboard KCM by hand
    # would be wiped on the next rebuild. Declare it instead.
    home-manager.users.${primaryUsername}.programs.plasma.configFile."kwinrc"."Wayland" = mkIf config.kde.enable {
      InputMethod = fcitx5Desktop;
    };
  };
}
