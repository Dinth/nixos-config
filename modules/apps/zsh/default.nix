{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf getExe getExe';
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in {
  config = mkIf cfg.enable {
    programs.zsh.enable = true;

    home-manager.users.${primaryUsername} = { config, ... }: {
      home.sessionVariables.LS_COLORS =
        lib.removeSuffix "\n" (builtins.readFile (
          pkgs.runCommand "generate-ls-colors" {} ''
            ${getExe pkgs.vivid} generate catppuccin-mocha > $out
          ''
        ));
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
          ignoreDups = true;
          ignoreSpace = true;
        };

        shellAliases = {
          cat = "${getExe pkgs.bat}";
          ls = "${getExe pkgs.eza} -l";
          tree = "${getExe pkgs.eza} --tree --all";
          top = "${getExe pkgs.btop}";
        };

        initContent = ''
          setopt EXTENDED_HISTORY HIST_SAVE_NO_DUPS INC_APPEND_HISTORY CORRECT HIST_REDUCE_BLANKS HIST_VERIFY INTERACTIVE_COMMENTS

          # Enable completion caching
          zstyle ':completion:*' use-cache on
          zstyle ':completion:*' cache-path "${config.xdg.cacheHome}/zsh/completions"

          # Reduce max errors to speed up completion
          zstyle ':completion:*' max-errors 1

          # Color completions using LS_COLORS
          zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

          # Enhanced completion styling
          zstyle ':completion:*' menu select
          zstyle ':completion:*' group-name '''
          zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
          zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
          zstyle ':completion:*:default' list-prompt '%S%M matches%s'

          # Case-insensitive path completion
          zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'

          # Partial completion suggestions
          zstyle ':completion:*' list-suffixes
          zstyle ':completion:*' expand prefix suffix

          autoload -Uz compinit

          local zcompdump="${config.xdg.cacheHome}/zsh/completions/.zcompdump"
          local zcompdump_zwc="$zcompdump.zwc"

          # Portable timestamp check - works on Linux and macOS
          if [[ ! -f "$zcompdump" ]]; then
            # Cache doesn't exist, rebuild
            compinit -d "$zcompdump"
          else
            # Cache exists - check if older than 24 hours using portable method
            local cache_mtime
            if command -v stat &>/dev/null; then
              # Try Linux stat first (more common in NixOS)
              cache_mtime=$(stat -c %Y "$zcompdump" 2>/dev/null) || \
              # Fall back to macOS stat
              cache_mtime=$(stat -f %m "$zcompdump" 2>/dev/null) || \
              # If stat fails entirely, assume cache is stale
              cache_mtime=0
            else
              cache_mtime=0
            fi

            local current_time=$(date +%s)
            local age=$((current_time - cache_mtime))

            if [[ $age -gt 86400 ]]; then
              # Older than 24 hours, rebuild
              compinit -d "$zcompdump"
            else
              # Fresh cache, use it
              compinit -C -d "$zcompdump"
            fi
          fi

          # Only compile if .zcompdump is newer than .zcompdump.zwc
          if [[ "$zcompdump" -nt "$zcompdump_zwc" ]] 2>/dev/null; then
            zcompile "$zcompdump" 2>/dev/null
          fi

          autoload -Uz add-zsh-hook

          setopt AUTO_PUSHD PUSHD_SILENT PUSHD_TO_HOME PUSHD_IGNORE_DUPS PUSHD_MINUS

          function lscontent() {
            local target="''${@:-.}"
            [[ ! -d "$target" ]] && { echo "lscontent: not a directory: $target" >&2; return 1; }

            ${getExe pkgs.tree} -I "node_modules|.git" "$target"
            echo ""
            echo "--- FILE CONTENTS ---"
            echo ""
            ${getExe pkgs.findutils} "$target" -type f \
              -not -path '*/.git/*' \
              -not -path '*/node_modules/*' \
              -not -path '*/flake.lock' \
              -exec sh -c "echo '--- FILE: {} ---'; ${getExe pkgs.bat} --plain '{}' 2>/dev/null || cat '{}'" sh \;
          }


          ${lib.optionalString (lib.hasAttr "zoxide" pkgs) ''
            function cd() {
              if [[ -n "$MC_SID" ]]; then
                builtin cd "$@"
              else
                z "$@"
              fi
            }
            function cdi() {
              local dir
              dir=$(zoxide query -i -- "\''${1:-}" | fzf --height=20 --border --ansi) && cd "$dir"
            }
            function cdq() {
              zoxide query --list -- "$@"
            }
            zle -N cdi
            bindkey '^Z' cdi
          ''}

          ${lib.optionalString (
            lib.any (tool: lib.hasAttr tool pkgs) ["wl-clipboard" "xclip" "xsel"]
          ) ''
            function pbcopy() {
              local content
              content="$(${getExe pkgs.bat} --plain "$@" 2>/dev/null || cat "$@")"

              ${lib.optionalString (lib.hasAttr "wl-clipboard" pkgs) ''
                if command -v ${getExe' pkgs.wl-clipboard "wl-copy"} &>/dev/null; then
                  echo -n "$content" | ${getExe' pkgs.wl-clipboard "wl-copy"}
                  return $?
                fi
              ''}

              ${lib.optionalString (lib.hasAttr "xclip" pkgs) ''
                if ${getExe pkgs.xclip} -version &>/dev/null 2>&1; then
                  echo -n "$content" | ${getExe pkgs.xclip} -selection clipboard
                  return $?
                fi
              ''}

              ${lib.optionalString (lib.hasAttr "xsel" pkgs) ''
                if ${getExe pkgs.xsel} --version &>/dev/null 2>&1; then
                  echo -n "$content" | ${getExe pkgs.xsel} -ib
                  return $?
                fi
              ''}

              echo "pbcopy: No clipboard utility found (wl-clipboard, xclip, or xsel)" >&2
              return 1
            }
          ''}

        '';
      };

      catppuccin.zsh-syntax-highlighting = {
        enable = true;
        flavor = "mocha";
      };
    };
  };
}
