{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf getExe getExe';
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
  # Captured from the system config here because `config` is shadowed by the
  # home-manager.users lambda below (where it refers to the HM config, which
  # has no theme.flavor). vivid is not a catppuccin/nix module, so its theme
  # name has to be interpolated explicitly.
  themeFlavor = config.theme.flavor;
in {
  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      # /etc/zshrc would otherwise run its own uncached compinit before
      # ~/.zshrc gets a say; the Home Manager completionInit below owns it.
      # enableCompletion stays on, so completion functions are still linked.
      enableGlobalCompInit = false;
    };

    home-manager.users.${primaryUsername} = {config, ...}: {
      home.sessionVariables.LS_COLORS = lib.removeSuffix "\n" (builtins.readFile (
        pkgs.runCommand "generate-ls-colors" {} ''
          ${getExe pkgs.vivid} generate catppuccin-${themeFlavor} > $out
        ''
      ));
      programs.zsh = {
        enable = true;
        # Keep zsh dotfiles in $HOME (legacy behaviour). The default flips to
        # $XDG_CONFIG_HOME/zsh once home.stateVersion >= "26.05".
        dotDir = config.home.homeDirectory;
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

        # Shell aliases live in modules/system/cli.nix
        # (environment.shellAliases), so they apply to every interactive
        # shell, not just zsh.

        # The one compinit per shell. It used to live in initContent, but HM's
        # default completionInit (a bare `compinit`) and NixOS's /etc/zshrc
        # each ran an uncached pass first, so this cached one ran third and
        # saved nothing: ~0.5 s per uncached pass against ~10 ms with -C.
        # Replacing completionInit rather than blanking it keeps compinit in
        # HM's early slot, before the zoxide/fzf/direnv integrations, which
        # only register their completions (compdef) once compinit has run.
        completionInit = ''
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

          _zcompdump="${config.xdg.cacheHome}/zsh/completions/.zcompdump"
          [[ -d ''${_zcompdump:h} ]] || mkdir -p ''${_zcompdump:h}
          # Full, audited compinit when the dump is missing or older than a day;
          # otherwise trust it (-C skips compaudit and the fpath rescan). The
          # mh+24 glob qualifier does the age test in-shell, on Linux and macOS
          # alike, without forking stat/date on every new shell.
          _zcompdump_stale=( $_zcompdump(N.mh+24) )
          if [[ ! -f $_zcompdump ]] || (( $#_zcompdump_stale )); then
            compinit -d "$_zcompdump"
          else
            compinit -C -d "$_zcompdump"
          fi
          if [[ $_zcompdump -nt $_zcompdump.zwc ]]; then
            zcompile "$_zcompdump" 2>/dev/null
          fi
          unset _zcompdump _zcompdump_stale
        '';

        initContent = ''
          setopt EXTENDED_HISTORY HIST_SAVE_NO_DUPS INC_APPEND_HISTORY CORRECT HIST_REDUCE_BLANKS HIST_VERIFY INTERACTIVE_COMMENTS

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
            # cd → z, but only for fuzzy queries. Anything that looks
            # like a path (contains /, starts with ., or is `-` / empty)
            # goes through builtin cd so typos surface as real errors
            # instead of silently teleporting somewhere via zoxide
            # fuzzy-match (e.g. `cd /etc/typo` shouldn't drop you in
            # the Trash because of a partial substring hit).
            function cd() {
              [[ -n "$MC_SID" ]] && { builtin cd "$@"; return; }
              if [[ $# -eq 0 || "$1" == "-" || "$1" == */* || "$1" == "." || "$1" == ".." ]]; then
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

          # Hint-once wrappers — keep the canonical command working
          # (so POSIX-shaped invocations don't break silently the way
          # they would with a hard alias to ripgrep/fd/difftastic) but
          # print a dim-grey reminder the first time per shell session
          # that a modern alternative exists. Sentinel env vars scoped
          # to the shell mean each new terminal nudges again.
          _modern_hint() {
            local tool=$1 modern=$2 desc=$3
            local var=_HINT_''${tool}
            if [[ -z ''${(P)var} ]]; then
              print -P "%F{8}▶ tip: '%F{cyan}$modern%F{8}' is available — $desc%f" >&2
              typeset -g $var=1
            fi
          }
          grep()     { _modern_hint grep     rg     "smart defaults, respects .gitignore";     command grep     "$@"; }
          find()     { _modern_hint find     fd     "intuitive syntax (e.g. 'fd .py src/')";   command find     "$@"; }
          diff()     { _modern_hint diff     difft  "structural diff that reads code";         command diff     "$@"; }
          dig()      { _modern_hint dig      doggo  "cleaner table output";                    command dig      "$@"; }
          nslookup() { _modern_hint nslookup doggo  "cleaner table output";                    command nslookup "$@"; }
          man()      { _modern_hint man      tldr   "quick example-based docs";                command man      "$@"; }
          htop()     { _modern_hint htop     btop   "modern TUI with GPU + sensors";           command htop     "$@"; }
          unzip()    { _modern_hint unzip    unar   "also handles rar / 7z / tar / etc.";      command unzip    "$@"; }

          # The old lib.hasAttr guards around these branches were tautological
          # (they test whether the attr exists in nixpkgs, which is always
          # true, not whether the tool is installed) — selection is a runtime
          # concern, decided by the checks below. Store-path references keep
          # all three tools in the closure, same as before.
          function pbcopy() {
            local content
            content="$(${getExe pkgs.bat} --plain "$@" 2>/dev/null || cat "$@")"

            if command -v ${getExe' pkgs.wl-clipboard "wl-copy"} &>/dev/null; then
              echo -n "$content" | ${getExe' pkgs.wl-clipboard "wl-copy"}
              return $?
            fi

            if ${getExe pkgs.xclip} -version &>/dev/null 2>&1; then
              echo -n "$content" | ${getExe pkgs.xclip} -selection clipboard
              return $?
            fi

            if ${getExe pkgs.xsel} --version &>/dev/null 2>&1; then
              echo -n "$content" | ${getExe pkgs.xsel} -ib
              return $?
            fi

            echo "pbcopy: No clipboard utility found (wl-clipboard, xclip, or xsel)" >&2
            return 1
          }

        '';
      };

      catppuccin.zsh-syntax-highlighting = {
        enable = true;
        # flavor inherits the global catppuccin.flavor (set from theme.flavor).
      };
    };
  };
}
