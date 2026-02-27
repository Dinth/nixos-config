{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkDefault;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    graphical = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable graphical environment.";
      };
    };
  };
  config = mkIf cfg.enable {
    services.xserver.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = with pkgs; [
      vlc
      libvlc
      libva
      libva-utils
      mesa
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
      mpv
      wl-clipboard
      libvdpau-va-gl
      shared-mime-info
    ];
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-lgc-plus
      corefonts
      vista-fonts
      nerd-fonts.fira-code
      ubuntu-classic
    ];
    fonts.fontconfig = {
      enable = mkDefault true;
      antialias = mkDefault true;
      subpixel.rgba = mkDefault "rgb";
      subpixel.lcdfilter = mkDefault "default";
      hinting = {
        enable = mkDefault true;
        style = mkDefault "full";
        autohint = mkDefault true;
      };
      allowBitmaps = mkDefault false;
    };
    orcaslicer.enable = mkDefault true;
    security.rtkit.enable = mkDefault true;
    services.colord.enable = mkDefault true;
    security.polkit.enable = mkDefault true;
    services.libinput.touchpad.naturalScrolling = mkDefault true;
    xdg.portal = {
      enable = true;
    };
    xdg.mime.enable = true;
    home-manager.users.${primaryUsername}.xdg = {
      enable = true;
      mimeApps.enable = true;
    };
  };
}
