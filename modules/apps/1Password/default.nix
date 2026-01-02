{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config._1password;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    _1password = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 1Password CLI";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      programs._1password.enable = true;
#      environment.systemPackages = with pkgs; [
#      ];
    })
    (mkIf (cfg.enable && config.graphical.enable) {
      programs._1password-gui.enable = true;
      programs._1password-gui.polkitPolicyOwners = [ "${config.primaryUser.name}" ];
      home-manager.users.${primaryUsername} = {
        xdg.configFile."autostart/1password.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=1Password
          # The --silent flag is key here; it starts 1Password minimized to the tray
          Exec=${pkgs._1password-gui}/bin/1password --silent
          Icon=1password
          Terminal=false
          StartupNotify=false
        '';
      };
    })
  ];
}
