{
  config,
  lib,
  pkgs,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = ["root" "@wheel"];
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

  # Command-not-found that actually works: shell hook into the
  # nix-index database. The nix-index-database flake input ships a
  # prebuilt db so we don't have to run `nix-index` ourselves.
  # Shadows nixos's built-in programs.command-not-found (which uses
  # an older, less-accurate channel-based database).
  programs.nix-index.enable = true;
  programs.command-not-found.enable = false;
}
