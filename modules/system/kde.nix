{ config, lib, pkgs, machineType ? "", ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
  inherit (config) specialArgs;

in
{
  options = {
    kde = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable full KDE features.";
      };
    };
  };
  config = mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;
    environment.systemPackages = with pkgs; [
      kdePackages.korganizer
      kdePackages.kontact
      kdePackages.kio-extras
      kdePackages.kio-fuse
      kdePackages.dolphin-plugins
      kdePackages.ktorrent
      kdePackages.kdepim-addons
      kdePackages.kompare
      kdePackages.kaccounts-providers
      kdePackages.kaccounts-integration
      kdePackages.skanlite
      kdePackages.phonon-vlc
      kdePackages.ksshaskpass
      kdePackages.ark
      kdePackages.kdegraphics-thumbnailers
      kdePackages.kimageformats
      kdePackages.qtimageformats
      kdePackages.ffmpegthumbs
      kdePackages.filelight # disk usage visualiser
      kdePackages.kcalc # calculator
      kdePackages.gwenview # image viewer
      haruna # KDE video player based on mpv
      kdePackages.ksystemlog
      libreoffice-qt
      kdePackages.isoimagewriter
    ] ++ lib.optionals (machineType == "tablet") [
      maliit-keyboard
      maliit-framework
    ];
    xdg.portal = {
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
      config.common.default = "kde";
    };
    services.desktopManager.plasma6.enableQt5Integration = true;
    services.blueman.enable = false; # Use KDE Bluetooth instead
    services.accounts-daemon.enable = true;
    programs.partition-manager.enable = true;
    programs.kde-pim.kontact = true;
    programs.kdeconnect.enable = true;
    qt = {
      enable = true;
      platformTheme = "kde";
      style = "breeze";
    };
#    security.wrappers = {
#      kwin_wayland = {
#        owner = "root";
#        group = "root";
#        source = "${lib.getExe' pkgs.kdePackages.kwin "kwin_wayland"}";
#      };
#    };
    # Session variables for KDE
    environment.sessionVariables = {
      # Common KDE variables
      # Qt theming
      QT_QPA_PLATFORMTHEME = "kde";
      QT_STYLE_OVERRIDE = "breeze";

      # KDE session type
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "KDE";

      NIXOS_OZONE_WL = "1"; # Electron apps Wayland support

      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # KDE Wayland session
      # KWIN_COMPOSE = "auto";
    };
    home-manager.users.${primaryUsername}.programs.plasma = {
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
        captureRectangularRegion = "Alt+$";
        captureActiveWindow = "Alt+%";
        captureCurrentMonitor = "Alt+#";
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
        # --- Applet 1014: IO ---
        {
          name = "org.kde.plasma.systemmonitor.diskactivity";
          position = { horizontal = 1696; vertical = 656; };
          size = { width = 352; height = 224; };
          config = {
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "SSD";
            };
            SensorColors."disk/nvme0n1/read" = "186,61,233";
            SensorColors."disk/nvme0n1/write" = "179,233,61";
            SensorColors."lmsensors/nvme-pci-0100/temp1" = "134,233,61";
            SensorLabels."disk/nvme0n1/read" = "Read Rate";
            SensorLabels."disk/nvme0n1/write" = "Write Rate";
            SensorLabels."lmsensors/nvme-pci-0100/temp1" = "Temperature";
            # Convert the JSON-like string to a proper Nix list
            Sensors.highPrioritySensorIds = [ "disk/nvme0n1/read" "disk/nvme0n1/write" ];
            Sensors.lowPrioritySensorIds = [ "lmsensors/nvme-pci-0100/temp1" ];
          };
        }

        # --- Applet 1016: Memory ---
        {
          name = "org.kde.plasma.systemmonitor.memory";
          position = { horizontal = 1696; vertical = 224; };
          size = { width = 352; height = 224; };
          config = {
            Appearance = {
              chartFace = "org.kde.ksysguard.piechart";
              title = "Memory";
            };
            SensorColors = {
              "memory/physical/applicationPercent" = "61,163,233";
              "memory/physical/bufferPercent" = "233,181,61";
              "memory/physical/cachePercent" = "233,82,61";
              "memory/swap/usedPercent" = "71,61,233";
            };
            SensorLabels."memory/swap/usedPercent" = "Swap";
            Sensors.highPrioritySensorIds = [ "memory/physical/applicationPercent" "memory/physical/bufferPercent" "memory/physical/cachePercent" "memory/swap/usedPercent" ];
          };
        }
        # --- Applet 1017: GPU ---
        {
          name = "org.kde.plasma.systemmonitor.gpu";
          position = { horizontal = 1696; vertical = 448; };
          size = { width = 352; height = 208; };
          config = {
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "GPU";
            };
            SensorColors = {
              "gpu/gpu1/temp3" = "233,107,61";
              "gpu/gpu1/usage" = "66,233,61";
              "gpu/gpu1/usedVram" = "61,233,224";
            };
            SensorLabels = {
              "gpu/gpu1/usage" = "GPU %";
              "gpu/gpu1/usedVram" = "Memory";
              "gpu/gpu1/temp3" = "Temperature";
            };
            Sensors = {
              highPrioritySensorIds = [ "gpu/gpu1/usage" "gpu/gpu1/usedVram" ];
              lowPrioritySensorIds = [ "gpu/gpu1/temp3" ];
            };
          };
        }
        # --- Applet 1018: Network ---
        {
          name = "org.kde.plasma.systemmonitor.network";
          position = { horizontal = 1696; vertical = 880; };
          size = { width = 352; height = 224; };
          config = {
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "Network";
            };
            SensorColors = {
              "network/all/download" = "89,233,61";
              "network/all/upload" = "233,61,140";
            };
            Sensors = {
              highPrioritySensorIds = [ "network/all/download" "network/all/upload" ];
            };
          };
        }
        # --- Applet 1020: CPU ---
        {
          name = "org.kde.plasma.systemmonitor.cpu";
          position = { horizontal = 1696; vertical = 0; };
          size = { width = 352; height = 224; };
          config = {
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "CPU";
            };
            SensorColors = {
              "cpu/all/averageFrequency" = "175,61,233";
              "cpu/all/averageTemperature" = "74,61,233";
              "cpu/all/usage" = "61,174,233";
            };
            SensorLabels = {
              "cpu/all/averageFrequency" = "Frequency";
              "cpu/all/averageTemperature" = "Temperature";
              "cpu/loadaverages/loadaverage1" = "Load avg 1m";
              "cpu/loadaverages/loadaverage15" = "Load avg 15m";
              "cpu/loadaverages/loadaverage5" = "Load avg 5m";
              "pressure/cpu/full10Sec" = "Pressure 10s";
            };
            Sensors.highPrioritySensorIds = [ "cpu/all/averageFrequency" "cpu/all/averageTemperature" ];
            Sensors.lowPrioritySensorIds = [ "cpu/loadaverages/loadaverage1" "cpu/loadaverages/loadaverage5" "cpu/loadaverages/loadaverage15" "pressure/cpu/full10Sec" ];
          };
        }
      ];
      configFile = {
        "spectaclerc" = {
          "GuiConfig"."captureMode" = 0;
          "ImageSave"."translatedScreenshotsFolder" = "Screenshots";
          "VideoSave" = {
            "preferredVideoFormat" = 2;
            "translatedScreencastsFolder" = "Screencasts";
          };
        };
        "kwinrc" = {
          "Xwayland"."Scale" = 1.25;
          "NightColor" = {
            "Active" = true;
            "NightTemperature" = 4800;
          };
        };
        "ktrashrc" = {
          "/home/${config.primaryUser.name}/.local/share/Trash" = {
            "Days" = 7;
            "LimitReachedAction" = 0;
            "Percent" = 10;
            "UseSizeLimit" = true;
            "UseTimeLimit" = false;
          };
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
        "kded6rc" = {
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
      };
    };
  };
}
