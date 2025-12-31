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
        colorScheme = "catppuccinMocha";
        CursorShape = 0;  # 0=Block, 1=I-Beam, 2=Underline
        UseFontBracketing = true;
        UseFontLineCharacters = true;
        font = {
          name = "FiraCode Nerd Font Med";
          size = 11;
        };
        extraConfig = {
          Appearance = {
            LineSpacing = 0;
            BoldIntense = true; # otherwise, nothing seems to even happen with bold fonts!
          };
          General = {
            DimWhenInactive = false;
            InvertSelectionColors = true;
            SemanticInputClick = true;
            SemanticUpDown = true;
            TerminalCenter = true;
            TerminalColumns = 160;
            TerminalRows = 40;
          };
          "Interaction Options" = {
            AllowEscapedLinks = false;
            AutoCopySelectedText = false;
            CopyTextAsHTML = false;
            OpenLinksByDirectClickEnabled = false;
            TextEditorCmd = 0;
            TrimLeadingSpacesInSelectedText = true;
            TrimTrailingSpacesInSelectedText = true;
            UnderlineFilesEnabled = true;
            WordCharacters = ":@-./_~?&=%+#";  # Characters considered part of words for double-click selection
            TripleClickMode = 0;  # 0=SelectWholeLine, 1=SelectForwardsFromCursor
          };
          "Scrolling" = {
            HistoryMode = 1;
            HistorySize = 40000;
            ScrollBarPosition = 2;
            ScrollFullPage = false;
          };
          "TabBar" = {
            TabBarPosition = 0;  # 0=Bottom, 1=Top
            CloseTabOnMiddleMouseButton = true;
            TabBarVisibility = 2;  # 0=AlwaysHideTabBar, 1=AlwaysShowTabBar, 2=ShowTabBarWhenNeeded
          };
          "Terminal Features" = {
            BellMode = 1;  # 0=None, 1=Visual, 2=System, 3=Both
            BlinkingCursorEnabled = true;
            FlowControlEnabled = true;
            UrlHintsModifiers = 67108864;  # Ctrl key modifier
          };
        };
      };
    };
  };
}
