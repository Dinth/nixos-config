{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf getExe getExe';
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    # System level: minimal
    programs.zsh.enable = true;

    # Home-manager: all user config here
    home-manager.users.${primaryUsername} = { config, ... }: {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        history = {
          size = 100000;
          save = 100000;
          path = "${config.xdg.dataHome}/zsh/history";
          extended = true;
          expireDuplicatesFirst = true;
          ignoreDups = true;
          ignoreSpace = true;
          ignoreAllDups = true;
          saveNoDups = true;
        };

        shellAliases = {
          cat = "${getExe pkgs.bat}";
          ls = "${getExe pkgs.eza} -l";
          tree = "${getExe pkgs.eza} --tree --all";
          top = "${getExe pkgs.btop}";
        };

        # Use initExtra (appends) instead of initContent (replaces)
        initContent = ''
          setopt EXTENDED_HISTORY HIST_SAVE_NO_DUPS INC_APPEND_HISTORY
          unsetopt SHARE_HISTORY

          export LS_COLORS="$(${getExe pkgs.vivid} generate catppuccin-mocha)"

          function lscontent() {
            ${getExe pkgs.tree} -I 'node_modules|.git' "''${@:-.}"
            echo ""
            echo "--- FILE CONTENTS ---"
            echo ""
            ${getExe pkgs.findutils} "''${@:-.}" -type f \
              -not -path '*/.git/*' \
              -not -path '*/node_modules/*' \
              -not -path '*/flake.lock' \
              -exec sh -c '
                echo "--- FILE: {} ---"
                ${getExe pkgs.bat} --plain "{}" 2>/dev/null || cat "{}"
              ' \;
          }

          ${lib.optionalString (lib.hasAttr "zoxide" pkgs) ''
            function cd() {
              if [[ -n "$MC_SID" ]]; then
                builtin cd "$@"
              else
                z "$@"
              fi
            }
          ''}

          ${lib.optionalString (lib.hasAttr "plasma-workspace" pkgs.kdePackages) ''
            function pbcopy() {
              ${getExe' pkgs.kdePackages.qttools "qdbus"} \
                org.kde.klipper /klipper setClipboardContents \
                "$(cat "$@")"
            }
          ''}

          if [[ -n "$KONSOLE_DBUS_SESSION" ]]; then
            precmd() { print -n $'\e]133;A\e\\'; }
            preexec() { print -n $'\e]133;C\e\\'; }
          fi
        '';
      };

      programs.starship = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          add_newline = false;
          format = "$directory$git_branch$git_status$character ";
          character = {
            success_symbol = "[❯](bold green)";
            error_symbol = "[❯](bold red)";
          };
          nix_shell = {
            disabled = false;
            impure_msg = "[impure](bold red)";
            format = "[$symbol$state]($style) ";
          };
        };
      };
    };
  };
}
