{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;

  catppuccin_konsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
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
        KonsoleWindow = {
          RememberWindowSize = false;
        };
      };
      profiles.Default = {
        name = "Default";
        command = "${pkgs.zsh}/bin/zsh";
        colorScheme = "catppuccinMocha";
        font = {
          name = "FiraCode Nerd Font Med";
          size = 11;
        };
        extraConfig = {
          Appearance = {
            LineSpacing = 0;
            BoldIntense = true; # otherwise, nothing seems to even happen with bold fonts!
            CursorShape = 0;  # 0=Block, 1=I-Beam, 2=Underline
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
          "TabBar" = {
            NewTabBehavior = 0;  # 0=After current tab, 1=At end
            ExpandTabWidth = false;  # Keep tabs compact
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
            WordCharacters = ":@-./_~?&=%+#";  # Characters considered part of words for double-click selection
            TripleClickMode = 0;  # 0=SelectWholeLine, 1=SelectForwardsFromCursor
            MiddleClickPasteMode = 0; # 0=paste from clipboard, 1=paste from X selection
          };
          "Scrolling" = {
            HistoryMode = 1;
            HistorySize = 40000;
            ScrollBarPosition = 2;
            ScrollFullPage = false;
            ReflowLines = true;  # Reflow lines when terminal is resized
            HighlightScrolledLines = true;
          };
          "TabBar" = {
            TabBarPosition = 0;  # 0=Bottom, 1=Top
            CloseTabOnMiddleMouseButton = true;
            TabBarVisibility = 2;  # 0=AlwaysHideTabBar, 1=AlwaysShowTabBar, 2=ShowTabBarWhenNeeded
          };
          "Terminal Features" = {
            BellMode = 1;  # 0=None, 1=Visual, 2=System, 3=Both
            BlinkingCursorEnabled = true;
            FlowControlEnabled = false;
            UrlHintsModifiers = 67108864;  # Ctrl key modifier
            BidiRenderingEnabled = true;
            LineNumbers = 0;  # 0=Disabled, 1=Left, 2=Right
          };
        };
      };
    };
  };
}
