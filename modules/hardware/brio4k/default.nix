{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.brio4k;
in
{
  options = {
    brio4k = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Logitech Brio 4K webcam support with V4L2 controls.";
      };
    };
  };

  config = mkIf cfg.enable {
    # V4L2 utilities for camera control
    environment.systemPackages = with pkgs; [
      v4l-utils      # v4l2-ctl for command-line camera control
      cameractrls    # GUI for webcam settings (supports Brio presets)
      ffmpeg         # For camera testing/capture
    ];

    # Ensure uvcvideo module is loaded with proper settings
    boot.extraModprobeConfig = ''
      # Increase USB buffer for 4K webcams
      options uvcvideo quirks=0x80
    '';

    # Ensure camera portal is available for applications
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    # udev rule for Logitech Brio 4K - ensure proper permissions
    services.udev.extraRules = ''
      # Logitech Brio 4K
      SUBSYSTEM=="video4linux", ATTR{name}=="Logitech BRIO", MODE="0660", GROUP="video", TAG+="uaccess"
    '';
  };
}
