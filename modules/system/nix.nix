{ config, lib, pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.settings.substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
  ];
  environment.systemPackages = with pkgs; [
    nix-diff
  ];
  programs.nh.enable = true;
}
