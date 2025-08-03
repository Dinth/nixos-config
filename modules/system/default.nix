{ config, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./gaming.nix
    ./graphical.nix
    ./kde.nix
    ./networking.nix
    ./security.nix
    ./virtualisation.nix
  ];
}
