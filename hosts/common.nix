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
  boot.tmp.useTmpfs = true;
  boot.tmp.cleanOnBoot = true;
  services.fwupd.enable = true;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };
}
