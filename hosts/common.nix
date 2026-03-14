{ config, pkgs, lib, machineType ? "desktop", ... }:
let
  inherit (lib) mkDefault mkIf;
in
{
  # Passwordless doas for servers (remote deployments have no TTY)
  security.doas.extraRules = mkIf (machineType == "server") (lib.mkForce [
    {
      users = [ config.primaryUser.name ];
      noPass = true;
      keepEnv = true;
    }
  ]);

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
