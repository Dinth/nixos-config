{ config, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./darwin.nix
    ./docker.nix
    ./gaming.nix
    ./graphical.nix
    ./locale.nix
    ./kde.nix
    ./networking.nix
    ./nix.nix
    ./security.nix
    ./virtualisation.nix
  ];
}
