{ config, lib, pkgs, ... }:
let
  catppuccin_konsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
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
  programs.konsole = {
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
    profiles.default = {
      name = "Default";
      colorScheme = "catppuccinMocha";
      font = {
        name = "FiraCode Nerd Font Med";
        size = 10;
      };
    };
  };
  programs.plasma = {
    enable = true;
    overrideConfig = true;
    input.keyboard.numlockOnStartup = "on";
    workspace = {
      clickItemTo = "select";
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      wallpaperPictureOfTheDay.provider = "simonstalenhag";
      cursor.theme = "catppuccin-mocha-dark-cursors";
    };
    spectacle.shortcuts = {
      captureRectangularRegion = "Ctrl+$";
      captureActiveWindow = "Ctrl+%";
      captureCurrentMonitor = "Ctrl+Shift+#";
        launch = "Print";
    };
    panels = [
    {
      location = "bottom";
      widgets = [
        # --- Applet 3: Application Launcher ---
        {
          name = "org.kde.plasma.kickoff";
          config.General = {
            favoritesPortedToKAstats = true;
          };
        }

        # --- Applet 4: Pager (Virtual Desktop Switcher) ---
        { name = "org.kde.plasma.pager"; }

        # --- Applet 5: Icon-Only Task Manager ---
        { name = "org.kde.plasma.icontasks"; }

        # --- Applet 6: Margins Separator (Spacer) ---
        { name = "org.kde.plasma.marginsseparator"; }

        # --- Applet 7: System Tray ---
        {
          name = "org.kde.plasma.systemtray";
          config.General = {
            extraItems = [
              "org.kde.plasma.devicenotifier" "org.kde.plasma.cameraindicator"
              "org.kde.plasma.mediacontroller" "org.kde.plasma.manage-inputmethod"
              "org.kde.plasma.notifications" "org.kde.plasma.keyboardindicator"
              "org.kde.kscreen" "org.kde.plasma.networkmanagement"
              "org.kde.plasma.volume" "org.kde.plasma.keyboardlayout"
              "org.kde.plasma.printmanager" "org.kde.kdeconnect"
              "org.kde.plasma.brightness" "org.kde.plasma.weather"
              "org.kde.plasma.bluetooth" "org.kde.plasma.battery"
              "org.kde.plasma.clipboard"
            ];
            knownItems = [
              "org.kde.plasma.devicenotifier" "org.kde.plasma.cameraindicator"
              "org.kde.plasma.mediacontroller" "org.kde.plasma.manage-inputmethod"
              "org.kde.plasma.clipboard" "org.kde.plasma.notifications"
              "org.kde.plasma.keyboardindicator" "org.kde.kscreen"
              "org.kde.plasma.networkmanagement" "org.kde.plasma.volume"
              "org.kde.plasma.keyboardlayout" "org.kde.plasma.printmanager"
              "org.kde.kdeconnect" "org.kde.plasma.battery"
              "org.kde.plasma.brightness" "org.kde.plasma.weather"
              "org.kde.plasma.bluetooth"
            ];
            shownItems = [ "org.kde.plasma.battery" "org.kde.plasma.clipboard" ];
          };
        }
        # --- Applet 19: Digital Clock ---
        {
          name = "org.kde.plasma.digitalclock";
          config.Appearance = {
            fontWeight = 400;
          };
        }

        # --- Applet 20: Show Desktop ---
        { name = "org.kde.plasma.showdesktop"; }
      ];
    }
  ];
    desktop.widgets = [
      {
        name = "org.kde.plasma.systemmonitor.net";
        # Geometry from ItemGeometries: Applet-39 -> 1696,656,352,208
        position = { horizontal = 1696; vertical = 656; };
        size = { width = 352; height = 224; };
        config = {
          Appearance = {
            chartFace = "org.kde.ksysguard.linechart";
            title = "Network Speed";
          };
          # Keys with special characters like '/' must be quoted
          SensorColors."network/all/download" = "61,174,233";
          SensorColors."network/all/upload" = "233,120,61";
          # Convert the JSON-like string to a proper Nix list
          Sensors.highPrioritySensorIds = [ "network/all/download" "network/all/upload" ];
        };
      }

      # --- Applet 40: General System Monitor (GPU) ---
      {
        name = "org.kde.plasma.systemmonitor";
        # Geometry from ItemGeometries: Applet-40 -> 1696,16,352,208
        position = { horizontal = 1696; vertical = 16; };
        size = { width = 352; height = 208; };
        config = {
          Appearance.chartFace = "org.kde.ksysguard.linechart";
          SensorColors = {
            "gpu/all/usage" = "142,233,61";
            "gpu/all/usedVram" = "61,130,233";
            "gpu/gpu1/coreFrequency" = "61,216,233";
            "gpu/gpu1/in0" = "61,233,115";
            "gpu/gpu1/memoryFrequency" = "233,61,108";
            "gpu/gpu1/power" = "233,231,61";
            "gpu/gpu1/totalVram" = "233,120,61";
            "gpu/gpu1/usage" = "61,174,233";
            # Double backslash is needed to escape the backslash in a Nix string
            "gpu/gpu\\d+/totalVram" = "61,233,98";
            "gpu/gpu\\d+/usage" = "233,61,186";
          };
          Sensors.highPrioritySensorIds = [ "gpu/all/usedVram" "gpu/all/usage" ];
        };
      }

      # --- Applet 41: CPU Monitor ---
      {
        name = "org.kde.plasma.systemmonitor.cpu";
        position = { horizontal = 1696; vertical = 224; };
        size = { width = 352; height = 224; };
        # Geometry from ItemGeometries: Applet-41 -> 1696,224,352,224
        config = {
          Appearance = {
            chartFace = "org.kde.ksysguard.linechart";
            title = "Total CPU Use";
          };
          SensorColors."cpu/all/usage" = "61,174,233";
          Sensors = {
            highPrioritySensorIds = [ "cpu/all/usage" ];
            lowPrioritySensorIds = [ "cpu/all/cpuCount" "cpu/all/coreCount" ];
            totalSensors = [ "cpu/all/usage" ];
          };
        };
      }

      # --- Applet 42: Memory Monitor ---
      {
        name = "org.kde.plasma.systemmonitor.memory";
        # Geometry from ItemGeometries: Applet-42 -> 1696,448,352,208
        position = { horizontal = 1696; vertical = 448; };
        size = { width = 352; height = 208; };
        config = {
          Appearance = {
            chartFace = "org.kde.ksysguard.linechart";
            title = "Memory Usage";
          };
          SensorColors = {
            "memory/physical/used" = "61,174,233";
            "memory/swap/used" = "233,61,155";
          };
          Sensors = {
            highPrioritySensorIds = [ "memory/physical/used" "memory/swap/used" ];
            # An empty JSON array becomes an empty Nix list
            lowPrioritySensorIds = [ ];
            totalSensors = [ "memory/physical/usedPercent" "memory/swap/usedPercent" ];
          };
        };
      }

      # --- Applet 44: Disk Activity Monitor ---
      {
        name = "org.kde.plasma.systemmonitor.diskactivity";
        # Geometry from ItemGeometries: Applet-44 -> 1696,864,352,224
        position = { horizontal = 1696; vertical = 864; };
        size = { width = 352; height = 224; };
        config = {
          Appearance = {
            chartFace = "org.kde.ksysguard.linechart";
            title = "Hard Disk Activity";
          };
          SensorColors = {
            "disk/all/read" = "233,120,61";
            "disk/all/write" = "61,174,233";
          };
          Sensors.highPrioritySensorIds = [ "disk/all/write" "disk/all/read" ];
        };
      }
    ];
    configFile = {
      "kwinrc" = {
        "Xwayland"."Scale" = 1.25;
        "NightColor" = {
          "Active" = true;
          "NightTemperature" = 4800;
        };
      };
      "ktrashrc" = {
        "\\/home\\/michal\\/.local\\/share\\/Trash"."Days" = 7;
        "\\/home\\/michal\\/.local\\/share\\/Trash"."LimitReachedAction" = 0;
        "\\/home\\/michal\\/.local\\/share\\/Trash"."Percent" = 10;
        "\\/home\\/michal\\/.local\\/share\\/Trash"."UseSizeLimit" = true;
        "\\/home\\/michal\\/.local\\/share\\/Trash"."UseTimeLimit" = false;
      };
      "krunnerrc"."General"."FreeFloating" = true;
      "kscreenlockerrc" = {
        "Greeter"."WallpaperPlugin" = "org.kde.potd";
        "Greeter/Wallpaper/org.kde.potd/General"."Provider" = "simonstalenhag";
      };
      "kiorc"."Confirmations" = {
        "ConfirmDelete" = true;
        "ConfirmEmptyTrash" = true;
        "ConfirmTrash" = false;
      };
      "kdeglobals" = {
        "PreviewSettings"."EnableRemoteFolderThumbnail" = false;
        "PreviewSettings"."MaximumRemoteSize" = 2097152;
        "KDE"."SingleClick" = false;
        "KFileDialog Settings" = {
          "Allow Expansion" = false;
          "Automatically select filename extension" = true;
          "Breadcrumb Navigation" = true;
          "Decoration position" = 2;
          "LocationCombo Completionmode" = 5;
          "PathCombo Completionmode" = 5;
          "Show Bookmarks" = false;
          "Show Full Path" = false;
          "Show Inline Previews" = true;
          "Show Preview" = false;
          "Show Speedbar" = true;
          "Show hidden files" = true;
          "Sort by" = "Name";
          "Sort directories first" = true;
          "Sort hidden files last" = true;
          "Sort reversed" = false;
          "Speedbar Width" = 140;
          "View Style" = "DetailTree";
        };
      };
      "kcminputrc"."Keyboard"."NumLock" = 0;
      "kded5rc" = {
        "Module-browserintegrationreminder"."autoload" = false;
        "Module-device_automounter"."autoload" = false;
      };
      "baloofilerc"."General" = {
        "exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
        "exclude filters version" = 9;
      };
      "dolphinrc" = {
        "ContentDisplay" = {
          "DirectorySizeMode" = "ContentSize";
          "RecursiveDirectorySizeLimit" = 20;
          "UsePermissionsFormat" = "CombinedFormat";
        };
        "General" = {
          "BrowseThroughArchives" = true;
          "FilterBar" = true;
          "RememberOpenedTabs" = false;
          "ShowFullPath" = true;
          "ShowFullPathInTitlebar" = true;
          "ShowStatusBar" = "FullWidth";
          "ShowToolTips" = true;
          "UseTabForSwitchingSplitView" = true;
          "ViewPropsTimestamp" = "2025,6,18,13,58,23.231";
        };
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };
        "Notification Messages"."warnAboutRisksBeforeActingAsAdmin" = false;
        "PreviewSettings"."Plugins" = "appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,ffmpegthumbs";
        "VersionControl"."enabledPlugins" = "Git";
      };
      "katerc" = {
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
        "Konsole" = {
          "RemoveExtension" = false;
          "RunPrefix" = "";
          "SetEditor" = false;
          "KonsoleEscKeyBehaviour" = true;
          "KonsoleEscKeyExceptions" = "vi,vim,nvim,git";
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
          "AllowedServerCommandLines" = "";
          "AutoHover" = true;
          "AutoImport" = true;
          "BlockedServerCommandLines" = "";
          "CompletionDocumentation" = true;
          "CompletionParens" = true;
          "Diagnostics" = true;
          "FormatOnSave" = false;
          "HighlightGoto" = true;
          "IncrementalSync" = false;
          "InlayHints" = false;
          "Messages" = true;
          "ReferencesDeclaration" = true;
          "SemanticHighlighting" = true;
          "ServerConfiguration" = "";
          "ShowCompletions" = true;
          "SignatureHelp" = true;
          "SymbolDetails" = false;
          "SymbolExpand" = true;
          "SymbolSort" = false;
          "SymbolTree" = true;
          "TypeFormatting" = false;
        };
      };
    };
  };
}
