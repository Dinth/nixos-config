{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.gaming;
in {
  options = {
    gaming = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gaming features.";
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
      openttd-jgrpp
    ];
  };
}
