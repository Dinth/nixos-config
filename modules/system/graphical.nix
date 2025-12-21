{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
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
      caido
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
      enable = true;
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "light";
      hinting.style = "full";
      allowBitmaps = false;
    };
    orcaslicer.enable = true;
    security.rtkit.enable = true;
    services.colord.enable = true;
    security.polkit.enable = true;
    services.libinput.touchpad.naturalScrolling = true;

    home-manager.users.${primaryUsername}.xdg = {
      enable = true;
      mimeApps.enable = true;
    };
  };
}
