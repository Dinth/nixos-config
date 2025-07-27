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
      "kwinrc"."NightColor"."Active" = true;
      "kwinrc"."NightColor"."NightTemperature" = 4800;
      "kwinrc"."Xwayland"."Scale" = 1.25;
      "ktrashrc"."\\/home\\/michal\\/.local\\/share\\/Trash"."Days" = 7;
      "ktrashrc"."\\/home\\/michal\\/.local\\/share\\/Trash"."LimitReachedAction" = 0;
      "ktrashrc"."\\/home\\/michal\\/.local\\/share\\/Trash"."Percent" = 10;
      "ktrashrc"."\\/home\\/michal\\/.local\\/share\\/Trash"."UseSizeLimit" = true;
      "ktrashrc"."\\/home\\/michal\\/.local\\/share\\/Trash"."UseTimeLimit" = false;
      "krunnerrc"."General"."FreeFloating" = true;
      "kscreenlockerrc"."Greeter"."WallpaperPlugin" = "org.kde.potd";
      "kscreenlockerrc"."Greeter/Wallpaper/org.kde.potd/General"."Provider" = "simonstalenhag";
      "kiorc"."Confirmations"."ConfirmDelete" = true;
      "kiorc"."Confirmations"."ConfirmEmptyTrash" = true;
      "kiorc"."Confirmations"."ConfirmTrash" = false;
      "kdeglobals"."PreviewSettings"."EnableRemoteFolderThumbnail" = false;
      "kdeglobals"."PreviewSettings"."MaximumRemoteSize" = 2097152;
      "kdeglobals"."KDE"."SingleClick" = false;
      "kdeglobals"."KFileDialog Settings"."Allow Expansion" = false;
      "kdeglobals"."KFileDialog Settings"."Automatically select filename extension" = true;
      "kdeglobals"."KFileDialog Settings"."Breadcrumb Navigation" = true;
      "kdeglobals"."KFileDialog Settings"."Decoration position" = 2;
      "kdeglobals"."KFileDialog Settings"."LocationCombo Completionmode" = 5;
      "kdeglobals"."KFileDialog Settings"."PathCombo Completionmode" = 5;
      "kdeglobals"."KFileDialog Settings"."Show Bookmarks" = false;
      "kdeglobals"."KFileDialog Settings"."Show Full Path" = false;
      "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
      "kdeglobals"."KFileDialog Settings"."Show Preview" = false;
      "kdeglobals"."KFileDialog Settings"."Show Speedbar" = true;
      "kdeglobals"."KFileDialog Settings"."Show hidden files" = false;
      "kdeglobals"."KFileDialog Settings"."Sort by" = "Name";
      "kdeglobals"."KFileDialog Settings"."Sort directories first" = true;
      "kdeglobals"."KFileDialog Settings"."Sort hidden files last" = false;
      "kdeglobals"."KFileDialog Settings"."Sort reversed" = false;
      "kdeglobals"."KFileDialog Settings"."Speedbar Width" = 140;
      "kdeglobals"."KFileDialog Settings"."View Style" = "DetailTree";
      "kcminputrc"."Keyboard"."NumLock" = 0;
      "kded5rc"."Module-browserintegrationreminder"."autoload" = false;
      "kded5rc"."Module-device_automounter"."autoload" = false;
      "katerc"."Konsole"."KonsoleEscKeyBehaviour" = true;
      "katerc"."Konsole"."KonsoleEscKeyExceptions" = "vi,vim,nvim,git";
      "baloofilerc"."General"."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
      "baloofilerc"."General"."exclude filters version" = 9;
      "dolphinrc"."ContentDisplay"."DirectorySizeMode" = "ContentSize";
      "dolphinrc"."ContentDisplay"."RecursiveDirectorySizeLimit" = 20;
      "dolphinrc"."ContentDisplay"."UsePermissionsFormat" = "CombinedFormat";
      "dolphinrc"."General"."BrowseThroughArchives" = true;
      "dolphinrc"."General"."FilterBar" = true;
      "dolphinrc"."General"."RememberOpenedTabs" = false;
      "dolphinrc"."General"."ShowFullPath" = true;
      "dolphinrc"."General"."ShowFullPathInTitlebar" = true;
      "dolphinrc"."General"."ShowStatusBar" = "FullWidth";
      "dolphinrc"."General"."ShowToolTips" = true;
      "dolphinrc"."General"."UseTabForSwitchingSplitView" = true;
      "dolphinrc"."General"."ViewPropsTimestamp" = "2025,6,18,13,58,23.231";
      "dolphinrc"."KFileDialog Settings"."Places Icons Auto-resize" = false;
      "dolphinrc"."KFileDialog Settings"."Places Icons Static Size" = 22;
      "dolphinrc"."Notification Messages"."warnAboutRisksBeforeActingAsAdmin" = false;
      "dolphinrc"."PreviewSettings"."Plugins" = "appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,ffmpegthumbs";
      "dolphinrc"."VersionControl"."enabledPlugins" = "Git";
      "katerc"."ColoredBrackets"."color1" = "#1275ef";
      "katerc"."ColoredBrackets"."color2" = "#f83c1f";
      "katerc"."ColoredBrackets"."color3" = "#9dba1e";
      "katerc"."ColoredBrackets"."color4" = "#e219e2";
      "katerc"."ColoredBrackets"."color5" = "#37d21c";
      "katerc"."General"."Allow Tab Scrolling" = true;
      "katerc"."General"."Auto Hide Tabs" = false;
      "katerc"."General"."Close After Last" = false;
      "katerc"."General"."Close documents with window" = true;
      "katerc"."General"."Cycle To First Tab" = true;
      "katerc"."General"."Days Meta Infos" = 30;
      "katerc"."General"."Diagnostics Limit" = 12000;
      "katerc"."General"."Diff Show Style" = 0;
      "katerc"."General"."Elide Tab Text" = false;
      "katerc"."General"."Enable Context ToolView" = false;
      "katerc"."General"."Expand Tabs" = false;
      "katerc"."General"."Icon size for left and right sidebar buttons" = 32;
      "katerc"."General"."Modified Notification" = false;
      "katerc"."General"."Mouse back button action" = 0;
      "katerc"."General"."Mouse forward button action" = 0;
      "katerc"."General"."Open New Tab To The Right Of Current" = false;
      "katerc"."General"."Output History Limit" = 100;
      "katerc"."General"."Output With Date" = false;
      "katerc"."General"."Recent File List Entry Count" = 10;
      "katerc"."General"."Restore Window Configuration" = true;
      "katerc"."General"."SDI Mode" = false;
      "katerc"."General"."Save Meta Infos" = true;
      "katerc"."General"."Show Full Path in Title" = false;
      "katerc"."General"."Show Menu Bar" = true;
      "katerc"."General"."Show Status Bar" = true;
      "katerc"."General"."Show Symbol In Navigation Bar" = true;
      "katerc"."General"."Show Tab Bar" = true;
      "katerc"."General"."Show Tabs Close Button" = true;
      "katerc"."General"."Show Url Nav Bar" = true;
      "katerc"."General"."Show output view for message type" = 1;
      "katerc"."General"."Show text for left and right sidebar" = false;
      "katerc"."General"."Show welcome view for new window" = true;
      "katerc"."General"."Startup Session" = "manual";
      "katerc"."General"."Stash new unsaved files" = true;
      "katerc"."General"."Stash unsaved file changes" = false;
      "katerc"."General"."Sync section size with tab positions" = false;
      "katerc"."General"."Tab Double Click New Document" = true;
      "katerc"."General"."Tab Middle Click Close Document" = true;
      "katerc"."General"."Tabbar Tab Limit" = 0;
      "katerc"."KTextEditor Document"."Allow End of Line Detection" = true;
      "katerc"."KTextEditor Document"."Auto Detect Indent" = true;
      "katerc"."KTextEditor Document"."Auto Reload If State Is In Version Control" = true;
      "katerc"."KTextEditor Document"."Auto Save" = false;
      "katerc"."KTextEditor Document"."Auto Save Interval" = 0;
      "katerc"."KTextEditor Document"."Auto Save On Focus Out" = false;
      "katerc"."KTextEditor Document"."BOM" = false;
      "katerc"."KTextEditor Document"."Backup Local" = false;
      "katerc"."KTextEditor Document"."Backup Prefix" = "";
      "katerc"."KTextEditor Document"."Backup Remote" = false;
      "katerc"."KTextEditor Document"."Backup Suffix" = "~";
      "katerc"."KTextEditor Document"."Camel Cursor" = true;
      "katerc"."KTextEditor Document"."Encoding" = "UTF-8";
      "katerc"."KTextEditor Document"."End of Line" = 0;
      "katerc"."KTextEditor Document"."Indent On Backspace" = true;
      "katerc"."KTextEditor Document"."Indent On Tab" = true;
      "katerc"."KTextEditor Document"."Indent On Text Paste" = true;
      "katerc"."KTextEditor Document"."Indentation Mode" = "normal";
      "katerc"."KTextEditor Document"."Indentation Width" = 2;
      "katerc"."KTextEditor Document"."Keep Extra Spaces" = false;
      "katerc"."KTextEditor Document"."Line Length Limit" = 10000;
      "katerc"."KTextEditor Document"."Newline at End of File" = true;
      "katerc"."KTextEditor Document"."On-The-Fly Spellcheck" = false;
      "katerc"."KTextEditor Document"."Overwrite Mode" = false;
      "katerc"."KTextEditor Document"."PageUp/PageDown Moves Cursor" = false;
      "katerc"."KTextEditor Document"."Remove Spaces" = 1;
      "katerc"."KTextEditor Document"."ReplaceTabsDyn" = true;
      "katerc"."KTextEditor Document"."Show Spaces" = 2;
      "katerc"."KTextEditor Document"."Show Tabs" = true;
      "katerc"."KTextEditor Document"."Smart Home" = true;
      "katerc"."KTextEditor Document"."Swap Directory" = "";
      "katerc"."KTextEditor Document"."Swap File Mode" = 1;
      "katerc"."KTextEditor Document"."Swap Sync Interval" = 15;
      "katerc"."KTextEditor Document"."Tab Handling" = 2;
      "katerc"."KTextEditor Document"."Tab Width" = 2;
      "katerc"."KTextEditor Document"."Trailing Marker Size" = 1;
      "katerc"."KTextEditor Document"."Use Editor Config" = true;
      "katerc"."KTextEditor Document"."Word Wrap" = false;
      "katerc"."KTextEditor Document"."Word Wrap Column" = 80;
      "katerc"."KTextEditor Renderer"."Animate Bracket Matching" = false;
      "katerc"."KTextEditor Renderer"."Auto Color Theme Selection" = true;
      "katerc"."KTextEditor Renderer"."Color Theme" = "Breeze Dark";
      "katerc"."KTextEditor Renderer"."Line Height Multiplier" = 1;
      "katerc"."KTextEditor Renderer"."Show Indentation Lines" = true;
      "katerc"."KTextEditor Renderer"."Show Whole Bracket Expression" = false;
      "katerc"."KTextEditor Renderer"."Text Font" = "FiraCode Nerd Font Med,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      "katerc"."KTextEditor Renderer"."Text Font Features" = "";
      "katerc"."KTextEditor Renderer"."Word Wrap Marker" = false;
      "katerc"."KTextEditor View"."Allow Mark Menu" = true;
      "katerc"."KTextEditor View"."Auto Brackets" = false;
      "katerc"."KTextEditor View"."Auto Center Lines" = 0;
      "katerc"."KTextEditor View"."Auto Completion" = true;
      "katerc"."KTextEditor View"."Auto Completion Preselect First Entry" = true;
      "katerc"."KTextEditor View"."Backspace Remove Composed Characters" = false;
      "katerc"."KTextEditor View"."Bookmark Menu Sorting" = 0;
      "katerc"."KTextEditor View"."Bracket Match Preview" = false;
      "katerc"."KTextEditor View"."Chars To Enclose Selection" = "<>(){}[]'\"`";
      "katerc"."KTextEditor View"."Cycle Through Bookmarks" = true;
      "katerc"."KTextEditor View"."Default Mark Type" = 1;
      "katerc"."KTextEditor View"."Dynamic Word Wrap" = true;
      "katerc"."KTextEditor View"."Dynamic Word Wrap Align Indent" = 80;
      "katerc"."KTextEditor View"."Dynamic Word Wrap At Static Marker" = false;
      "katerc"."KTextEditor View"."Dynamic Word Wrap Indicators" = 1;
      "katerc"."KTextEditor View"."Dynamic Wrap not at word boundaries" = false;
      "katerc"."KTextEditor View"."Enable Accessibility" = true;
      "katerc"."KTextEditor View"."Enable Tab completion" = false;
      "katerc"."KTextEditor View"."Enter To Insert Completion" = true;
      "katerc"."KTextEditor View"."Fold First Line" = false;
      "katerc"."KTextEditor View"."Folding Bar" = true;
      "katerc"."KTextEditor View"."Folding Preview" = true;
      "katerc"."KTextEditor View"."Icon Bar" = false;
      "katerc"."KTextEditor View"."Input Mode" = 0;
      "katerc"."KTextEditor View"."Keyword Completion" = true;
      "katerc"."KTextEditor View"."Line Modification" = true;
      "katerc"."KTextEditor View"."Line Numbers" = true;
      "katerc"."KTextEditor View"."Max Clipboard History Entries" = 20;
      "katerc"."KTextEditor View"."Maximum Search History Size" = 100;
      "katerc"."KTextEditor View"."Mouse Paste At Cursor Position" = false;
      "katerc"."KTextEditor View"."Multiple Cursor Modifier" = 134217728;
      "katerc"."KTextEditor View"."Persistent Selection" = false;
      "katerc"."KTextEditor View"."Scroll Bar Marks" = false;
      "katerc"."KTextEditor View"."Scroll Bar Mini Map All" = true;
      "katerc"."KTextEditor View"."Scroll Bar Mini Map Width" = 60;
      "katerc"."KTextEditor View"."Scroll Bar MiniMap" = true;
      "katerc"."KTextEditor View"."Scroll Bar Preview" = true;
      "katerc"."KTextEditor View"."Scroll Past End" = false;
      "katerc"."KTextEditor View"."Search/Replace Flags" = 140;
      "katerc"."KTextEditor View"."Shoe Line Ending Type in Statusbar" = false;
      "katerc"."KTextEditor View"."Show Documentation With Completion" = true;
      "katerc"."KTextEditor View"."Show File Encoding" = true;
      "katerc"."KTextEditor View"."Show Folding Icons On Hover Only" = true;
      "katerc"."KTextEditor View"."Show Line Count" = false;
      "katerc"."KTextEditor View"."Show Scrollbars" = 0;
      "katerc"."KTextEditor View"."Show Statusbar Dictionary" = true;
      "katerc"."KTextEditor View"."Show Statusbar Highlighting Mode" = true;
      "katerc"."KTextEditor View"."Show Statusbar Input Mode" = true;
      "katerc"."KTextEditor View"."Show Statusbar Line Column" = true;
      "katerc"."KTextEditor View"."Show Statusbar Tab Settings" = true;
      "katerc"."KTextEditor View"."Show Word Count" = false;
      "katerc"."KTextEditor View"."Smart Copy Cut" = true;
      "katerc"."KTextEditor View"."Statusbar Line Column Compact Mode" = true;
      "katerc"."KTextEditor View"."Text Drag And Drop" = true;
      "katerc"."KTextEditor View"."User Sets Of Chars To Enclose Selection" = "";
      "katerc"."KTextEditor View"."Vi Input Mode Steal Keys" = false;
      "katerc"."KTextEditor View"."Vi Relative Line Numbers" = false;
      "katerc"."KTextEditor View"."Word Completion" = true;
      "katerc"."KTextEditor View"."Word Completion Minimal Word Length" = 3;
      "katerc"."KTextEditor View"."Word Completion Remove Tail" = true;
      "katerc"."Konsole"."RemoveExtension" = false;
      "katerc"."Konsole"."RunPrefix" = "";
      "katerc"."Konsole"."SetEditor" = false;
      "katerc"."filetree"."editShade" = "31,81,106";
      "katerc"."filetree"."listMode" = false;
      "katerc"."filetree"."middleClickToClose" = false;
      "katerc"."filetree"."shadingEnabled" = true;
      "katerc"."filetree"."showCloseButton" = false;
      "katerc"."filetree"."showFullPathOnRoots" = false;
      "katerc"."filetree"."showToolbar" = true;
      "katerc"."filetree"."sortRole" = 0;
      "katerc"."filetree"."viewShade" = "81,49,95";
      "katerc"."lspclient"."AllowedServerCommandLines" = "";
      "katerc"."lspclient"."AutoHover" = true;
      "katerc"."lspclient"."AutoImport" = true;
      "katerc"."lspclient"."BlockedServerCommandLines" = "";
      "katerc"."lspclient"."CompletionDocumentation" = true;
      "katerc"."lspclient"."CompletionParens" = true;
      "katerc"."lspclient"."Diagnostics" = true;
      "katerc"."lspclient"."FormatOnSave" = false;
      "katerc"."lspclient"."HighlightGoto" = true;
      "katerc"."lspclient"."IncrementalSync" = false;
      "katerc"."lspclient"."InlayHints" = false;
      "katerc"."lspclient"."Messages" = true;
      "katerc"."lspclient"."ReferencesDeclaration" = true;
      "katerc"."lspclient"."SemanticHighlighting" = true;
      "katerc"."lspclient"."ServerConfiguration" = "";
      "katerc"."lspclient"."ShowCompletions" = true;
      "katerc"."lspclient"."SignatureHelp" = true;
      "katerc"."lspclient"."SymbolDetails" = false;
      "katerc"."lspclient"."SymbolExpand" = true;
      "katerc"."lspclient"."SymbolSort" = false;
      "katerc"."lspclient"."SymbolTree" = true;
      "katerc"."lspclient"."TypeFormatting" = false;

    };
  };
}
