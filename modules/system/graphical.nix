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
    services.xserver.xkb = {
      layout = "pl";
      variant = "legacy";
      options = "terminate:ctrl_alt_bksp,kpdl:dot";
    };

    services.xserver.enable = true;

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.systemPackages = with pkgs; [
      vlc
      libvlc
    ];
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-lgc-plus
      noto-fonts-extra
      corefonts
      vista-fonts
      nerd-fonts.fira-code
    ];
    fonts.fontconfig = {
      enable = true;
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "light";
      hinting.style = "full";
      allowBitmaps = false;
    };

    security.rtkit.enable = true;
    services.colord.enable = true;
    security.polkit.enable = true;

    home-manager.users.${primaryUsername}.xdg = {
      enable = true;
      mimeApps.enable = true;
    };
  };
}
