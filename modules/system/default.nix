{ config, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./gaming.nix
    ./graphical.nix
    ./kde.nix
    ./security.nix
    ./virtualisation.nix
  ];
}
