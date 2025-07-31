{ config, lib, pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName  = "Michal Gawronski-Kot";
    userEmail = "michal@gawronskikot.com";
    extraConfig = {
      url = {
        "ssh://git@github.com" = {
          insteadOf = [ "https://github.com" "gh" ];
        };
      };
      url = {
        "ssh://git@bitbucket.org" = {
          insteadOf = "https://bitbucket.org";
        };
      };
      url = {
        "ssh://git@gitlab.com" = {
          insteadOf = "https://gitlab.com";
        };
      };
    };
  };
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        identityFile = [
          "~/.ssh/id_ed25519_sk_rk_1"
          "~/.ssh/id_ed25519_sk_rk_2"
          "~/.ssh/id_ed25519_sk_rk_3"
        ];
        identitiesOnly = true;
      };
    };
  };
  programs.eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      theme = "catppuccin.yml";
      extraOptions = [
        "--classify"
        "--group-directories-first"
        "--header"
        "--mounts"
        "--smart-group"
    ];
  };
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
      cat = "${pkgs.bat}/bin/bat";
      ls = "${pkgs.eza}/bin/eza -l";
      tree = "${pkgs.eza}/bin/eza --tree --all";
      htop = "${pkgs.btop}/bin/btop";
    };
    initContent = ''
      function lscontent {
        tree -I 'node_modules|.git'
        printf "\n--- FILE CONTENTS ---\n\n"
        find . -type f \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/flake.lock' \
        -exec sh -c '
        # For each file found by find, do the following:
          echo "--- FILE: {} ---"
          cat "{}"
          echo
        ' \;
      }
      function cd {
        if [[ -n "$MC_SID" ]]; then
          builtin cd "$@"
        else
          z "$@"
        fi
      }
      function pbcopy {
        qdbus org.kde.klipper /klipper setClipboardContents "$(cat "$@")"
      }
      export LS_COLORS="$(vivid generate catppuccin-mocha)"
    '';
  };
  programs.btop = {
    enable = true;
    settings = {
#      color_theme = "catppuccin_macchiato";
      truecolor = "True";
    };
  };
  programs.bat = {
    enable = true;
    config = {
#      theme = "Catppuccin Macchiato";
      map-syntax = ".ignore:Git Ignore";
      style = "numbers,changes";
    };
#     themes = {
#       Catppuccin-macchiato = {
#         src = pkgs.fetchFromGitHub {
#           owner = "catppuccin";
#           repo = "bat";
#           rev = "699f60fc8ec434574ca7451b444b880430319941";
#           sha256 = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
#         };
#         file = "Catppuccin-macchiato.tmTheme";
#       };
#     };
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  nixpkgs.overlays = [
    (self: super: {
      weechat = super.weechat.override {
        configure = { availablePlugins, ... }: {
          plugins = with availablePlugins; [ python ];
          scripts = with super.weechatScripts; [
            wee-slack
          ];
          init = ''
            /set irc.look.server_buffer independent
            /set plugins.var.python.slack.files_download_location "~/Downloads/weeslack"
            /set plugins.var.python.slack.auto_open_threads true
            /set plugins.var.python.slack.never_away true
            /set plugins.var.python.slack.render_emoji_as_string true
          '';
        };
      };
    })
  ];
}
