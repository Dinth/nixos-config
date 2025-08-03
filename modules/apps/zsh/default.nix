 { config, lib, pkgs,...}:
let
  inherit (lib) mkIf;
  cfg = config.cli;
in
{
  cfg = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history = {
        save = 100000;
        size = 100000;
        expireDuplicatesFirst = true;
        ignoreDups = true;
        ignoreSpace = true;
        ignorePatterns = ["rm *" "pkill *" "kill *" "killall *"];
      };
      shellAliases = {
        cat = "${lib.getExe pkgs.bat}";
        ls = "${lib.getExe pkgs.eza} -l";
        tree = "${lib.getExe pkgs.eza} --tree --all";
        top = "${lib.getExe pkgs.btop}";
      };

      initContent = ''
        function lscontent {
          ${lib.getExe pkgs.tree} -I 'node_modules|.git'
          ${lib.getExe' pkgs.coreutils "printf"} "\n--- FILE CONTENTS ---\n\n"
          ${lib.getExe pkgs.findutils} . -type f \
          -not -path '*/.git/*' \
          -not -path '*/node_modules/*' \
          -not -path '*/flake.lock' \
          -exec ${lib.getExe' pkgs.bash "sh"} -c '
          # For each file found by find, do the following:
            ${lib.getExe' pkgs.coreutils "echo"} "--- FILE: {} ---"
            ${lib.getExe' pkgs.coreutils "cat"} "{}"
            ${lib.getExe' pkgs.coreutils "echo"}
          ' \;
        }
      '' +
        ( lib.optionalString (pkgs.zoxide != null) ''
            function cd {
              if [[ -n "$MC_SID" ]]; then
                builtin cd "$@"
              else
                z "$@"
              fi
            }
          ''
        ) +
        ( lib.optionalString (pkgs.kdePackages.plasma-workspace != null) ''
            function pbcopy {
              ${lib.getExe' pkgs.kdePackages.qttools "qdbus"} org.kde.klipper /klipper setClipboardContents "$(${lib.getExe' pkgs.coreutils "cat"} "$@")"
            }
          ''
        ) +
      ''
        export LS_COLORS="$(${lib.getExe pkgs.vivid} generate catppuccin-mocha)"
      '';
    };
  };
}
