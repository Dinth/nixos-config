{ config, pkgs, ... }:
{
  imports = [
   ../system/kde.nix
   ../system/gaming.nix
  ];
  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "legacy";
    options = "terminate:ctrl_alt_bksp,kpdl:dot";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings.General.DisplayServer = "wayland";
    autoNumlock = true;
  };
  services.desktopManager.plasma6.enable = true;

  programs.kde-pim.kontact = true;
  programs.kdeconnect.enable = true;

  programs.gamemode.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

  programs.virt-manager.enable = true;

}
