{ config, pkgs, lib, ... }:
let
  inherit (lib) mkDefault;
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  # Bootloader.
  # Use latest kernel.
  boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;
#  boot.tmp.cleanOnBoot = true;
  services.fwupd.enable = true;
  ssh.enable = true;
}
