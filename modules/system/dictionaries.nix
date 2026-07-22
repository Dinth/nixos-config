{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.dictionaries;
  primaryUsername = config.primaryUser.name;

  # Hunspell is the format every modern spell checker actually reads:
  # LibreOffice, Thunderbird, GTK apps (via enchant), and Qt/KDE apps (via
  # sonnet_hunspell.so). Sonnet and enchant both discover dictionaries by
  # scanning $XDG_DATA_DIRS/hunspell, which systemPackages populates at
  # /run/current-system/sw/share/hunspell.
  #
  # The -large variants are the SCOWL level-70 wordlists — roughly double the
  # entries of the default level-60 build. More entries means both fewer false
  # positives and a wider candidate pool for suggestions, which is the whole
  # point here.
  hunspellDictionaries = with pkgs.hunspellDicts; [
    en_GB-large
    en_US-large # US spellings are still "correct" in most of what I write
    pl_PL
  ];

  # DICPATH is the escape hatch for the handful of consumers that don't walk
  # XDG_DATA_DIRS themselves (LibreOffice's bundled hunspell being the notable
  # one). Point it at a single merged tree rather than N store paths.
  dictionaryPath = pkgs.symlinkJoin {
    name = "hunspell-dictionaries";
    paths = hunspellDictionaries;
  };

  # Provider order for enchant (GTK apps, WebKitGTK, gspell). nuspell is the
  # modern C++ rewrite of hunspell by the same maintainers: same .dic/.aff
  # files, but a better-ranked suggestion algorithm. Keep hunspell as the
  # fallback and drop aspell to last — its suggestions are the narrow ones.
  enchantOrdering = ''
    *:nuspell,hunspell,aspell
  '';

  # Sonnet stores config via QSettings("KDE", "Sonnet") -> ~/.config/KDE/Sonnet.conf.
  # Ungrouped keys land in [General]. Verified against sonnet 6.26 settingsimpl.cpp.
  #
  # Handed to plasma-manager rather than xdg.configFile: KDE/Sonnet.conf is in
  # plasma-manager's default resetFiles, and write_config.py deletes every reset
  # file it doesn't itself manage (`reset_files - set(d.keys())`). Its activation
  # entry runs after writeBoundary, so it removed the Home Manager symlink right
  # after HM created it -- force = true doesn't help, the file was simply gone.
  #
  # preferredLanguages stays "en_GB, pl_PL": QSettings parses a comma-bearing
  # value into a QStringList for restore()'s .toStringList(), and plasma-manager's
  # escape() passes commas and interior spaces through untouched.
  sonnetConf = {
    defaultClient = "hunspell";
    defaultLanguage = "en_GB";
    preferredLanguages = "en_GB, pl_PL";
    autodetectLanguage = true;
    backgroundCheckerEnabled = true;
    checkerEnabledByDefault = true;
    checkUppercase = false;
    skipRunTogether = true;
  };
in {
  options = {
    dictionaries = {
      enable = mkOption {
        type = lib.types.bool;
        # Spell checking only matters where there's something to type into.
        default = config.graphical.enable;
        description = "Enable system-wide English + Polish spell checking dictionaries.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      hunspellDictionaries
      ++ (with pkgs; [
        hunspell # CLI + libhunspell for everything that links it
        nuspell # preferred enchant backend
        enchant # the abstraction layer GTK apps go through
      ]);

    environment.sessionVariables.DICPATH = "${dictionaryPath}/share/hunspell";

    home-manager.users.${primaryUsername} = {
      xdg.configFile."enchant/enchant.ordering".text = enchantOrdering;

      # autodetectLanguage lets Sonnet switch dictionaries per paragraph, so a
      # Polish reply inside an English thread stops being flagged wholesale.
      programs.plasma.configFile."KDE/Sonnet.conf".General =
        mkIf config.kde.enable sonnetConf;
    };
  };
}
