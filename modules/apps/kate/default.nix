{ config, lib, pkgs,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nil
    ];
    home-manager.users.${primaryUsername} = {
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
        mimeApps.defaultApplications = {
          "x-scheme-handler/applescript" = "Kate.desktop"; # applescript:// urls
          "application/x-plist" = "Kate.desktop"; # mac plist files
          "text/x-applescript" = "Kate.desktop"; # applescript
        };
      };
      home.file.".config/kate/lspclient/settings.json".text = ''
        {
          "servers": {
            "nix": {
              "command": ["nil"],
              "url": "https://github.com/oxalica/nil",
              "highlightingModeRegex": "^Nix$"
            }
          }
        }
      '';
    };
  };
}
