{ config, pkgs, ... }:
{
  imports = [
    ./cli.nix
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
