{ config, pkgs, lib, machineType ? "desktop", ... }:
let
  inherit (lib) mkDefault;
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  # Kernel: stable for servers, latest for desktops/tablets
  boot.kernelPackages = mkDefault (
    if machineType == "server"
    then pkgs.linuxPackages
    else pkgs.linuxPackages_latest
  );
#  boot.tmp.cleanOnBoot = true;
  services.fwupd.enable = true;
}
