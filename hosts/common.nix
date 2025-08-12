{ config, pkgs, lib, ... }:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  # Bootloader.
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
#  boot.tmp.cleanOnBoot = true;
  services.fwupd.enable = true;
  ssh.enable = true;
}
