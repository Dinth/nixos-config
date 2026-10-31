{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;

  # Read at profile open by HM's sync add-on, so the secrets never reach the
  # store and prefs21.db staying a store symlink doesn't log us out.
  syncWith = prefix: {
    url = "https://anki.wickhay.uk/";
    usernameFile = config.age.secrets."${prefix}-username".path;
    keyFile = config.age.secrets."${prefix}-key".path;
    autoSync = true;
    syncMedia = true;
  };

  # Anki has two independent update checks, both run right after the profile
  # opens: the program check (meta["check_for_updates"], the Preferences
  # checkbox) and the add-on check against AnkiWeb. The program is updated by
  # the flake, and add-ons live read-only in the store via withAddons, so
  # neither has anything to act on. Stubbing them in an add-on rather than
  # seeding the pref works because add-ons load before loadProfile, and
  # survives the HM module rewriting prefs21.db from its own options.
  noUpdateCheckAddon = pkgs.anki-utils.buildAnkiAddon {
    pname = "nix-no-update-check";
    version = "1.0";
    src = pkgs.writeTextDir "__init__.py" ''
      import aqt

      mw = aqt.mw
      mw.pm.check_for_updates = lambda: False


      def _skip_addon_update_check(on_done=None):
          # loadProfile chains setup_auto_update off this callback.
          if on_done:
              on_done([])


      mw.maybe_check_for_addon_updates = _skip_addon_update_check
    '';
  };
in {
  # Anki rides the kde.enable toggle, so it lands on the desktop and tablet but
  # not the headless server -- the same gate dictionaries.nix and the input
  # method use, and a flashcard app is only useful where there's a screen.
  #
  # pkgs.anki, not anki-bin: the HM module needs `withAddons`, which only the
  # source build has, and anki-bin also lags it by several releases. The source
  # build is built by Hydra, so it's still a cache download, not a local compile.
  config = mkIf cfg.enable {
    # Username and sync key per sync-server account (the anki-sync stack on
    # omv). Both come from modules/apps/anki/sync-login.sh <prefix>, which logs
    # in once and writes them; re-run it after a password change.
    age.secrets = lib.genAttrs (lib.concatMap (prefix: ["${prefix}-username" "${prefix}-key"]) ["anki-sync" "anki-sync-paulina"]) (name: {
      file = ../../../secrets/${name}.age;
      owner = primaryUsername;
      group = "users";
      mode = "0400";
    });

    home-manager.users.${primaryUsername}.programs.anki = {
      enable = true;
      # Matches i18n.defaultLocale, and setting it also skips the first-run
      # language picker.
      language = "en_GB";
      addons = [noUpdateCheckAddon];
      # prefs21.db becomes a store symlink, so profiles must be declared or
      # the existing collection under "User 1/" is no longer listed.
      profiles = {
        "User 1" = {
          default = true;
          sync = syncWith "anki-sync";
        };
        # Second account on the sync server, picked from File > Switch Profile.
        Paulina.sync = syncWith "anki-sync-paulina";
      };
    };
  };
}
