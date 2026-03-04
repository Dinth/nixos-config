{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.steam;
  primaryUsername = config.primaryUser.name;
in
{
  options.steam = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.gaming.enable;
      description = "Enable Steam and related gaming tools.";
    };
  };
  config = mkIf cfg.enable {
    hardware.steam-hardware.enable = true;
    programs.steam.enable = true;
    programs.gamemode.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
    ];
    systemd.settings.Manager.DefaultLimitNOFILE = 1048576;
    home-manager.users.${primaryUsername} = { config, ... }: {
      xdg.userDirs.extraConfig.XDG_GAME_DIR = "${config.home.homeDirectory}/Games";
      xdg.mimeApps = {
        defaultApplications."x-scheme-handler/steam" = "steam.desktop";
        associations.added."x-scheme-handler/steam" = "steam.desktop";
      };
    };
  };
}
