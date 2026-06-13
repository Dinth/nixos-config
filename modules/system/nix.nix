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
  # Public key for nix-community.cachix.org. Without it, Nix silently
  # refuses every path that cache signs and falls back to cache.nixos.org
  # or a local rebuild — so the substituter line above was dead weight
  # until this was added. cache.nixos.org's own key is a NixOS default and
  # is merged in automatically, so it isn't repeated here.
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
