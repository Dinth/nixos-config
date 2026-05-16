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

    # vm.max_map_count: many EAC/BattlEye titles (Hogwarts Legacy, Star Citizen)
    # crash with the kernel default of 1048576.
    boot.kernel.sysctl."vm.max_map_count" = 2147483642;
    # split_lock_mitigate=1 (default) throttles games doing atomic split-lock ops.
    boot.kernelParams = ["split_lock_mitigate=0"];

    environment.systemPackages = with pkgs; [
      (lutris.override {
        extraPkgs = pkgs:
          with pkgs; [
            wineWowPackages.staging
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
      winetricks
      umu-launcher
      wineWowPackages.staging
      openttd-jgrpp
    ];
  };
}
