{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../secrets/deployment.nix
  ];
}
