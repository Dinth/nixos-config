{ config, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./gaming.nix
    ./kde.nix
    ./security.nix
  ];
}
