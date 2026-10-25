{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.languagetool;
  primaryUsername = config.primaryUser.name;
in {
  # Points LibreOffice at the shared LanguageTool server on omv. Nothing runs
  # locally: when omv is unreachable each app falls back to what it already
  # has (hunspell spelling everywhere, Chrome's own spellcheck). Chrome and
  # Kate read cfg.url from their own modules.
  options.languagetool = {
    enable = mkOption {
      type = lib.types.bool;
      # Grammar checking only matters where there's something to type into.
      default = config.graphical.enable;
      description = "Point LanguageTool-capable apps at the omv LanguageTool server.";
    };

    url = mkOption {
      type = lib.types.str;
      default = "http://10.10.1.13:8010";
      description = "Base URL of the LanguageTool server (the API lives under /v2).";
    };
  };

  # LibreOffice: built-in remote LanguageTool checker, made the grammar
  # checker for the languages we write in (replacing Lightproof for English).
  # libreoffice-qt comes from kde.nix, so follow that toggle.
  config = mkIf (cfg.enable && config.kde.enable) {
    home-manager.users.${primaryUsername} = hm: {
      home.activation.libreofficeLanguagetool = hm.lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${pkgs.python3.interpreter} ${./libreoffice-xcu.py} \
          "${hm.config.xdg.configHome}/libreoffice/4/user/registrymodifications.xcu" \
          "${cfg.url}/v2" en-GB en-US pl-PL
      '';
    };
  };
}
