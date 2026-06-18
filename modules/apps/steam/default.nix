{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.steam;
  primaryUsername = config.primaryUser.name;
in {
  options.steam = {
    enable = mkOption {
      type = lib.types.bool;
      default = config.gaming.enable;
      description = "Enable Steam and related gaming tools.";
    };
  };
  config = mkIf cfg.enable {
    hardware.steam-hardware.enable = true;

    # bubblewrap 0.11+ dropped setuid support, but programs.steam — when
    # gamescopeSession.enable and programs.gamescope.capSysNice are both set —
    # points Steam's FHS sandbox at /run/wrappers/bin/bwrap and creates that
    # wrapper setuid root. A setuid bwrap built without setuid support aborts
    # with "setuid use of bubblewrap is not supported in this build", so Steam
    # never launches. Unprivileged user namespaces work on this host, so keep
    # the wrapper (the FHS env hardcodes its path) but drop the setuid bit and
    # let bwrap sandbox via userns instead.
    security.wrappers.bwrap.setuid =
      lib.mkIf config.programs.gamescope.capSysNice (lib.mkForce false);
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [pkgs.proton-ge-bin];
      protontricks.enable = true;
    };
    programs.gamemode.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
      goverlay
    ];
    systemd.settings.Manager.DefaultLimitNOFILE = 1048576;
    home-manager.users.${primaryUsername} = {config, ...}: {
      xdg.userDirs.extraConfig.XDG_GAME_DIR = "${config.home.homeDirectory}/Games";
      xdg.mimeApps = {
        defaultApplications."x-scheme-handler/steam" = "steam.desktop";
        associations.added."x-scheme-handler/steam" = "steam.desktop";
      };
    };
  };
}
