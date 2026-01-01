{ config, lib, pkgs,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
    customServers = {
    nix = {
      command = [ "${pkgs.nixd}/bin/nixd" ];
      url = "https://github.com/nix-community/nixd";
      highlightingModeRegex = "^Nix$";
      rootIndicationFileNames = [ "flake.nix" "flake.lock" "default.nix" ];
      settings = {
        nixd = {
          formatting = { command = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ]; };
          options = {
            nixos = {
              expr = ''(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.${config.networking.hostName}.options'';
            };
            home_manager = {
              expr = ''(builtins.getFlake (builtins.toString ./.)).homeConfigurations."${primaryUsername}@${config.networking.hostName}".options'';
            };
          };
        };
      };
    };
    yaml = {
      command = [ "${pkgs.yaml-language-server}/bin/yaml-language-server" "--stdio" ];
      url = "https://github.com/redhat-developer/yaml-language-server";
      highlightingModeRegex = "^YAML$";
    };
    bash = {
      command = [ "${pkgs.bash-language-server}/bin/bash-language-server" "start" ];
      url = "https://github.com/bash-lsp/bash-language-server";
      highlightingModeRegex = "^Bash$";
    };
    python = {
      command = [ "${pkgs.python3.withPackages (ps: [ ps.python-lsp-server ps.python-lsp-ruff ])}/bin/pylsp" "--check-parent-process" ];
      url = "https://github.com/python-lsp/python-lsp-server";
      highlightingModeRegex = "^Python$";
      settings = { pylsp = { plugins = { ruff = { enabled = true; }; pycodestyle = { enabled = false; }; }; }; };
    };
    xml = {
      command = [ "${pkgs.lemminx}/bin/lemminx" ];
      url = "https://github.com/redhat-developer/vscode-xml";
      highlightingModeRegex = "^XML$";
    };
    json = {
      command = [ "${pkgs.vscode-json-languageserver}/bin/vscode-json-languageserver" "--stdio" ];
      url = "https://github.com/microsoft/vscode";
      highlightingModeRegex = "^JSON$";
    };
  };
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        nixd
        yaml-language-server
        bash-language-server
        (python3.withPackages (ps: [
            ps.python-lsp-server
            ps.python-lsp-ruff
          ]
          )
        )
        vscode-json-languageserver
        lemminx
        nix-doc
        nixfmt-rfc-style
        statix
        nix-diff
        nix-tree
        manix
        deadnix
      ];
      programs.kate = {
        enable = true;
        editor = {
          font = {
            family = "FiraCode Nerd Font Med";
            pointSize = 10;
          };
          indent = {
            replaceWithSpaces = true;
            width = 2;
          };
          tabWidth = 2;
        };
      };
      xdg = {
        dataFile = {
          "mime/packages/x-plist.xml".text = ''
            <?xml version="1.0" encoding="UTF-8"?>
            <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
              <mime-type type="application/x-plist">
                <comment>Apple Property List</comment>
                <glob pattern="*.plist"/>
              </mime-type>
            </mime-info>
          '';
          "mime/packages/x-applescript.xml".text = ''
            <?xml version="1.0" encoding="UTF-8"?>
            <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
              <mime-type type="text/x-applescript">
                <comment>AppleScript Source</comment>
                <glob pattern="*.applescript"/>
              </mime-type>
            </mime-info>
          '';
        };
        mimeApps = {
          enable = true;
          defaultApplications = {
            "x-scheme-handler/applescript" = "kate.desktop";
            "application/x-plist" = "kate.desktop";
            "text/x-applescript" = "kate.desktop";
            "text/x-nix" = "kate.desktop";
            "application/x-nix" = "kate.desktop";
            "text/plain" = "kate.desktop";
            "text/x-shellscript" = "kate.desktop";
            "text/x-yaml" = "kate.desktop";
          };
        };
        configFile."kate/lspclient/settings.json" = {
          force = true;
          text = builtins.toJSON {
            servers = {
              nix = {
                command = [ "${pkgs.nixd}/bin/nixd" ];
              };
            };
          };
        };
      };

      # Use plasma-manager for Kate configuration
      programs.plasma.configFile."katerc" = {
        "ColoredBrackets" = {
          "color1" = "#1275ef";
          "color2" = "#f83c1f";
          "color3" = "#9dba1e";
          "color4" = "#e219e2";
          "color5" = "#37d21c";
        };
        "General" = {
          "Allow Tab Scrolling" = true;
          "Auto Hide Tabs" = false;
          "Close After Last" = false;
          "Close documents with window" = true;
          "Cycle To First Tab" = true;
          "Days Meta Infos" = 30;
          "Diagnostics Limit" = 12000;
          "Diff Show Style" = 0;
          "Elide Tab Text" = false;
          "Enable Context ToolView" = false;
          "Expand Tabs" = false;
          "Icon size for left and right sidebar buttons" = 32;
          "Modified Notification" = false;
          "Mouse back button action" = 0;
          "Mouse forward button action" = 0;
          "Open New Tab To The Right Of Current" = false;
          "Output History Limit" = 100;
          "Output With Date" = false;
          "Recent File List Entry Count" = 10;
          "Restore Window Configuration" = true;
          "SDI Mode" = false;
          "Save Meta Infos" = true;
          "Show Full Path in Title" = false;
          "Show Menu Bar" = true;
          "Show Status Bar" = true;
          "Show Symbol In Navigation Bar" = true;
          "Show Tab Bar" = true;
          "Show Tabs Close Button" = true;
          "Show Url Nav Bar" = true;
          "Show output view for message type" = 1;
          "Show text for left and right sidebar" = false;
          "Show welcome view for new window" = true;
          "Startup Session" = "manual";
          "Stash new unsaved files" = true;
          "Stash unsaved file changes" = false;
          "Sync section size with tab positions" = false;
          "Tab Double Click New Document" = true;
          "Tab Middle Click Close Document" = true;
          "Tabbar Tab Limit" = 0;
          "ShowMetaInformation" = true;
        };
        "Kate Plugins" = {
          "kateprojectplugin" = true;
          "kategoritblameplugin" = true;
          "lspclientplugin" = true;
          "katekonsoleplugin" = true;
          "kateformatterplugin" = true;
        };
        "KTextEditor Document" = {
          "Allow End of Line Detection" = true;
          "Auto Detect Indent" = true;
          "Auto Reload If State Is In Version Control" = true;
          "Auto Save" = false;
          "Auto Save Interval" = 0;
          "Auto Save On Focus Out" = false;
          "BOM" = false;
          "Backup Local" = false;
          "Backup Prefix" = "";
          "Backup Remote" = false;
          "Backup Suffix" = "~";
          "Camel Cursor" = true;
          "Encoding" = "UTF-8";
          "End of Line" = 0;
          "Indent On Backspace" = true;
          "Indent On Tab" = true;
          "Indent On Text Paste" = true;
          "Indentation Mode" = "normal";
          "Indentation Width" = 2;
          "Keep Extra Spaces" = false;
          "Line Length Limit" = 10000;
          "Newline at End of File" = true;
          "On-The-Fly Spellcheck" = false;
          "Overwrite Mode" = false;
          "PageUp/PageDown Moves Cursor" = false;
          "Remove Spaces" = 1;
          "ReplaceTabsDyn" = true;
          "Show Spaces" = 2;
          "Show Tabs" = true;
          "Smart Home" = true;
          "Swap Directory" = "";
          "Swap File Mode" = 1;
          "Swap Sync Interval" = 15;
          "Tab Handling" = 2;
          "Tab Width" = 2;
          "Trailing Marker Size" = 1;
          "Use Editor Config" = true;
          "Word Wrap" = false;
          "Word Wrap Column" = 80;
        };
        "KTextEditor Renderer" = {
          "Animate Bracket Matching" = false;
          "Auto Color Theme Selection" = true;
          "Color Theme" = "Breeze Dark";
          "Line Height Multiplier" = 1;
          "Show Indentation Lines" = true;
          "Show Whole Bracket Expression" = false;
          "Text Font" = "FiraCode Nerd Font Med,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          "Text Font Features" = "";
          "Word Wrap Marker" = false;
        };
        "KTextEditor View" = {
          "Allow Mark Menu" = true;
          "Auto Brackets" = false;
          "Auto Center Lines" = 0;
          "Auto Completion" = true;
          "Auto Completion Preselect First Entry" = true;
          "Backspace Remove Composed Characters" = false;
          "Bookmark Menu Sorting" = 0;
          "Bracket Match Preview" = false;
          "Chars To Enclose Selection" = "<>(){}[]'\"`";
          "Cycle Through Bookmarks" = true;
          "Default Mark Type" = 1;
          "Dynamic Word Wrap" = true;
          "Dynamic Word Wrap Align Indent" = 80;
          "Dynamic Word Wrap At Static Marker" = false;
          "Dynamic Word Wrap Indicators" = 1;
          "Dynamic Wrap not at word boundaries" = false;
          "Enable Accessibility" = true;
          "Enable Tab completion" = false;
          "Enter To Insert Completion" = true;
          "Fold First Line" = false;
          "Folding Bar" = true;
          "Folding Preview" = true;
          "Icon Bar" = false;
          "Input Mode" = 0;
          "Keyword Completion" = true;
          "Line Modification" = true;
          "Line Numbers" = true;
          "Max Clipboard History Entries" = 20;
          "Maximum Search History Size" = 100;
          "Mouse Paste At Cursor Position" = false;
          "Multiple Cursor Modifier" = 134217728;
          "Persistent Selection" = false;
          "Scroll Bar Marks" = false;
          "Scroll Bar Mini Map All" = true;
          "Scroll Bar Mini Map Width" = 60;
          "Scroll Bar MiniMap" = true;
          "Scroll Bar Preview" = true;
          "Scroll Past End" = false;
          "Search/Replace Flags" = 140;
          "Shoe Line Ending Type in Statusbar" = false;
          "Show Documentation With Completion" = true;
          "Show File Encoding" = true;
          "Show Folding Icons On Hover Only" = true;
          "Show Line Count" = false;
          "Show Scrollbars" = 0;
          "Show Statusbar Dictionary" = true;
          "Show Statusbar Highlighting Mode" = true;
          "Show Statusbar Input Mode" = true;
          "Show Statusbar Line Column" = true;
          "Show Statusbar Tab Settings" = true;
          "Show Word Count" = false;
          "Smart Copy Cut" = true;
          "Statusbar Line Column Compact Mode" = true;
          "Text Drag And Drop" = true;
          "User Sets Of Chars To Enclose Selection" = "";
          "Vi Input Mode Steal Keys" = false;
          "Vi Relative Line Numbers" = false;
          "Word Completion" = true;
          "Word Completion Minimal Word Length" = 3;
          "Word Completion Remove Tail" = true;
        };
        "filetree" = {
          "editShade" = "31,81,106";
          "listMode" = false;
          "middleClickToClose" = false;
          "shadingEnabled" = true;
          "showCloseButton" = false;
          "showFullPathOnRoots" = false;
          "showToolbar" = true;
          "sortRole" = 0;
          "viewShade" = "81,49,95";
        };
        "lspclient" = {
          "AllowedServerCommandLines" = lib.strings.concatStringsSep ";" (
            map (s: baseNameOf (builtins.elemAt s.command 0))
            (lib.attrValues customServers)
          );
          "AutoHover" = true;
          "AutoImport" = true;
          "BlockedServerCommandLines" = "";
          "CompletionDocumentation" = true;
          "CompletionParens" = true;
          "Diagnostics" = true;
          "FormatOnSave" = true;
          "HighlightGoto" = true;
          "IncrementalSync" = true;
          "InlayHints" = true;
          "Messages" = true;
          "ReferencesDeclaration" = true;
          "SemanticHighlighting" = true;
          "ServerConfiguration" = "${config.users.users.${primaryUsername}.home}/.config/kate/lspclient/settings.json";
          "ShowCompletions" = true;
          "SignatureHelp" = true;
          "SymbolDetails" = true;
          "SymbolExpand" = true;
          "SymbolSort" = true;
          "SymbolTree" = true;
          "TypeFormatting" = true;
        };
      };
    };
  };
}
