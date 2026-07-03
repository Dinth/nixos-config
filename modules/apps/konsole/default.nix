{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;

  catppuccin_konsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };

  # The Default profile follows the system-wide theme.flavor. The SSH and
  # OpenCode profiles deliberately use different flavors as a visual cue for
  # which context you're in, so they stay pinned below.
  defaultColorScheme =
    {
      latte = "catppuccinLatte";
      frappe = "catppuccinFrappe";
      macchiato = "catppuccinMacchiato";
      mocha = "catppuccinMocha";
    }.${
      config.theme.flavor
    };

  # All three profiles share the same font.
  baseFont = {
    name = "FiraCode Nerd Font Med";
    size = 11;
  };

  # Shared profile settings. The per-profile blocks below deep-merge their
  # own overrides onto this via lib.recursiveUpdate, so only the deltas
  # (tab titles, dimensions, bell/scrollback, link handling …) live in each
  # profile instead of the full block being copy-pasted three times.
  baseProfileExtraConfig = {
    Appearance = {
      LineSpacing = 0;
      BoldIntense = true;
      CursorShape = 0;
      UseFontBracketing = true;
      UseFontLineCharacters = true;
      AntiAliasFonts = true;
      BidiTableDirOverride = true;
    };
    General = {
      DimWhenInactive = false;
      InvertSelectionColors = true;
      SemanticInputClick = true;
      SemanticUpDown = true;
      TerminalCenter = true;
      TerminalColumns = 160;
      TerminalRows = 40;
      Environment = "TERM=xterm-256color,COLORTERM=truecolor";
      LocalTabTitleFormat = "%d : %n";
      RemoteTabTitleFormat = "%h : %u";
      StartInCurrentSessionDir = true;
      ShowTerminalSizeHint = true;
    };
    Monitor = {
      ActivityMode = 1;
      SilenceMode = 1;
      SilenceSeconds = 20;
    };
    "Interaction Options" = {
      AllowEscapedLinks = false;
      UnderlineLinksEnabled = true;
      AutoCopySelectedText = false;
      CopyTextAsHTML = false;
      OpenLinksByDirectClickEnabled = false;
      TextEditorCmd = 0;
      TrimLeadingSpacesInSelectedText = true;
      TrimTrailingSpacesInSelectedText = true;
      UnderlineFilesEnabled = true;
      WordCharacters = ":@-./_~?&=%+#";
      TripleClickMode = 0;
      MiddleClickPasteMode = 0;
    };
    Scrolling = {
      HistoryMode = 1;
      HistorySize = 40000;
      ScrollBarPosition = 2;
      ScrollFullPage = false;
      ReflowLines = true;
      HighlightScrolledLines = true;
    };
    TabBar = {
      TabBarPosition = 0;
      CloseTabOnMiddleMouseButton = true;
      TabBarVisibility = 2;
    };
    "Terminal Features" = {
      BellMode = 1;
      BlinkingCursorEnabled = true;
      FlowControlEnabled = false;
      UrlHintsModifiers = 67108864;
      BidiRenderingEnabled = true;
      LineNumbers = 0;
    };
  };

  mkProfileExtraConfig = overrides: lib.recursiveUpdate baseProfileExtraConfig overrides;
in {
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.konsole = {
      enable = true;
      customColorSchemes = {
        catppuccinLatte = catppuccin_konsole + /themes/catppuccin-latte.colorscheme;
        catppuccinFrappe = catppuccin_konsole + /themes/catppuccin-frappe.colorscheme;
        catppuccinMacchiato = catppuccin_konsole + /themes/catppuccin-macchiato.colorscheme;
        catppuccinMocha = catppuccin_konsole + /themes/catppuccin-mocha.colorscheme;
      };
      defaultProfile = "Default";
      extraConfig = {
        "Konsole" = {
          RemoveExtension = false;
          RunPrefix = "";
          SetEditor = false;
          KonsoleEscKeyBehaviour = true;
          KonsoleEscKeyExceptions = "vi,vim,nvim,git";
        };
        KonsoleWindow = {
          RememberWindowSize = false;
        };
      };
      profiles.Default = {
        name = "Default";
        command = "${pkgs.zsh}/bin/zsh";
        colorScheme = defaultColorScheme;
        font = baseFont;
        extraConfig = baseProfileExtraConfig;
      };
      profiles.SSH = {
        name = "SSH - 10.10.1.13";
        command = "${pkgs.openssh}/bin/ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 root@10.10.1.13";
        colorScheme = "catppuccinFrappe";
        font = baseFont;
        extraConfig = mkProfileExtraConfig {
          General = {
            RemoteTabTitleFormat = "[SSH] %h : %u";
            StartInCurrentSessionDir = false;
          };
          TabBar = {
            NewTabBehavior = 0;
            ExpandTabWidth = false;
          };
        };
      };
      profiles.OpenCode = {
        name = "OpenCode";
        command = "${pkgs.opencode}/bin/opencode";
        colorScheme = "catppuccinMacchiato";
        font = baseFont;
        extraConfig = mkProfileExtraConfig {
          General = {
            TerminalColumns = 180;
            TerminalRows = 50;
            Environment = "TERM=xterm-256color,COLORTERM=truecolor,SHELL=${pkgs.zsh}/bin/zsh";
            LocalTabTitleFormat = "[OpenCode] %d";
            RemoteTabTitleFormat = "[OpenCode] %h";
            ShowTerminalSizeHint = false;
          };
          # SilenceMode is off here, so the inherited SilenceSeconds is inert.
          Monitor = {
            ActivityMode = 0;
            SilenceMode = 0;
          };
          "Interaction Options" = {
            AllowEscapedLinks = true;
            CopyTextAsHTML = true;
            TripleClickMode = 1;
          };
          Scrolling = {
            HistorySize = 100000;
          };
          "Terminal Features" = {
            BellMode = 0;
          };
        };
      };
    };
  };
}
