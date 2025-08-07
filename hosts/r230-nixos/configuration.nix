{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../secrets/deployment.nix
  ];
  networking.hostName = "r230-nixos";
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };
  system.stateVersion = "25.11";

  cli.enable = true;
  graphical.enable = false;
  kde.enable = false;
  _1password.enable = false;
  _1password.gui = true;
  gaming.enable = false;
  virtualisation.enable = false;
  logitech.enable = false;
  amd_gpu.enable = false;
  printers.enable = false;
  weechat.enable = false;
}
