{ config, lib, pkgs,...}:
let
  inherit (lib) mkIf;
  cfg = config.kde;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        nil
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
        mimeApps.defaultApplications = {
          "x-scheme-handler/applescript" = "kate.desktop"; # applescript:// urls
          "application/x-plist" = "kate.desktop"; # mac plist files
          "text/x-applescript" = "kate.desktop"; # applescript
        };
      };
      xdg.configFile."katerc".text = ''
        [Kate Plugins]
        kateprojectplugin=true
        kategitblameplugin=true
        lspclientplugin=true
        katekonsoleplugin=true

        [General]
        ShowMetaInformation=true
      '';
      xdg.configFile."kate/lspclientrc".text = ''
          [General]
          ShowNotifications=false
          AutoImportCompletion=true

          [LSP]
          AutoStart=true
          CompletionDocumentation=true
          Diagnostics=true
          IncrementalSync=true
        '';
      xdg.configFile."kate/lspclient/settings.json".text =
      builtins.toJSON {
        servers = {
          nix = {
            command = [ "nil" ];
            url = "https://github.com/oxalica/nil";
            highlightingModeRegex = "^Nix$";
            rootIndicationFileNames = [ "flake.nix" "flake.lock" "default.nix" ];
          };
          yaml = {
            command = [ "yaml-language-server" "--stdio" ];
            url = "https://github.com/redhat-developer/yaml-language-server";
            highlightingModeRegex = "^YAML$";
            root = ".";
          };
          bash = {
            command = [ "bash-language-server" "start" ];
            url = "https://github.com/bash-lsp/bash-language-server";
            highlightingModeRegex = "^Bash$";
            root = ".";
          };
          python = {
            command = [ "pylsp" "--check-parent-process" ];
            url = "https://github.com/python-lsp/python-lsp-server";
            highlightingModeRegex = "^Python$";
            root = ".";
            settings = {
              pylsp = {
                plugins = {
                  ruff.enabled = true;
                  pycodestyle.enabled = false;
                };
              };
            };
          };
          xml = {
            command = [ "lemminx" ];
            url = "https://github.com/redhat-developer/vscode-xml";
            highlightingModeRegex = "^XML$";
            root = ".";
          };
          json = {
            command = [ "vscode-json-languageserver" "--stdio" ];
            url = "https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server";
            highlightingModeRegex = "^JSON$";
            root = ".";
          };
        };
      };
    };
  };
}
