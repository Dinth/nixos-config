{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;

  # Unpacks Diablo/Hellfire and Heroes 3 data from the GOG installers on the
  # NAS into the per-user data dirs DevilutionX and VCMI read.
  gogGameData = pkgs.writeShellApplication {
    name = "gog-game-data";
    runtimeInputs = with pkgs; [coreutils findutils innoextract];
    text =
      builtins.replaceStrings
      ["@gogLibrary@" "@heroes3Language@"]
      [cfg.gogLibrary cfg.heroes3Language]
      (builtins.readFile ./gog-game-data.sh);
  };
in {
  options = {
    gaming = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gaming features.";
      };
      gogLibrary = mkOption {
        type = lib.types.str;
        default = "/mnt/omv/Data/Games/GOG";
        description = "Directory of GOG offline installers (one folder per game) to import engine data from.";
      };
      heroes3Language = mkOption {
        type = lib.types.enum ["en" "pl"];
        default = "en";
        description = "Which Heroes 3 Complete installer to feed VCMI.";
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernelModules = ["ntsync"];

    # sched-ext userspace scheduler tuned for interactive/gaming latency:
    # LAVD (Latency-criticality Aware Virtual Deadline) prioritises the
    # wake-up chains games sit on over batch work. Needs CONFIG_SCHED_CLASS_EXT
    # (kernel ≥ 6.12 — gaming hosts run linuxPackages_latest). Reversible at
    # runtime with `systemctl stop scx` (falls back to EEVDF).
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    programs.gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # Allow processes in the gamemode group to renice down to -10 (matches
    # general.renice above). Without this, gamemoded logs:
    #   "RLIMIT_NICE is <= 20, unable to use setpriority safely"
    security.pam.loginLimits = [
      {
        domain = "@gamemode";
        item = "nice";
        type = "-";
        value = "-10";
      }
    ];

    environment.systemPackages = with pkgs; [
      (lutris.override {
        extraPkgs = pkgs:
          with pkgs; [
            wineWow64Packages.staging
            winetricks
            dxvk
            vkd3d
            vkd3d-proton
            gamescope
            gamemode
            mangohud
            umu-launcher
            cabextract
            p7zip
            samba
            gst_all_1.gstreamer
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-plugins-bad
            gst_all_1.gst-libav
          ];
      })
      heroic
      protontricks
      protonplus
      winetricks
      umu-launcher
      wineWow64Packages.staging
      openttd-jgrpp # nixpkgs bundles OpenGFX/OpenSFX/OpenMSX base sets
      # Open-source engines; game data comes from the GOG installers.
      vcmi # Heroes 3 (RoE+AB+SoD data imported by gog-game-data below)
      devilutionx # Diablo + Hellfire (data imported by gog-game-data below)
      innoextract # unpack GOG setup_*.exe for the above
      gogGameData # manual re-run: gog-game-data
      (callPackage ./opentyrian2000-engaged.nix {})
    ];

    # Import the GOG data once per user. The script skips games already
    # imported and exits cleanly when the NAS is unreachable, so it just
    # retries on the next login. No RemainAfterExit: `systemctl --user start
    # gog-game-data` re-runs it after dropping a new installer on the NAS.
    home-manager.users.${primaryUsername}.systemd.user.services.gog-game-data = {
      Unit.Description = "Import GOG game data for DevilutionX and VCMI";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe gogGameData;
        TimeoutStartSec = "30min";
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
