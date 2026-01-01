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

          DIRSTACKSIZE=20
          DIRSTACKFILE="${config.xdg.cacheHome}/zsh/dirstack"

          setopt AUTO_PUSHD PUSHD_SILENT PUSHD_TO_HOME PUSHD_IGNORE_DUPS PUSHD_MINUS

          # Load on startup only
          if [[ -f "$DIRSTACKFILE" ]] && (( ''${#dirstack} == 0 )); then
            dirstack=(''${(f)"$(<"$DIRSTACKFILE")"})
          fi

          # Use atomic write with temp file
          chpwd_dirstack() {
            local tmpfile="$DIRSTACKFILE.$$"
            local dirstack_content

            # Build content safely
            printf -v dirstack_content '%s\n' "$PWD" "''${(u)dirstack[@]}"

            # Atomic write with validation
            if printf '%s' "$dirstack_content" > "$tmpfile"; then
              mv -f "$tmpfile" "$DIRSTACKFILE" || rm -f "$tmpfile"
            else
              rm -f "$tmpfile"
            fi
          }

          add-zsh-hook -Uz chpwd chpwd_dirstack

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
          ''}

          ${lib.optionalString (lib.hasAttr "qttools" pkgs.kdePackages) ''
            function pbcopy() {
              ${getExe' pkgs.kdePackages.qttools "qdbus"} \
                org.kde.klipper /klipper setClipboardContents \
                "$(${getExe pkgs.bat} --plain "$@" 2>/dev/null || cat "$@")"
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
