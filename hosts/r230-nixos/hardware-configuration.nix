{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  services.qemuGuest.enable = true;

  boot.loader.grub.enable = true; # Use the boot drive for GRUB
  boot.loader.grub.devices = [ "nodev" ];

}
