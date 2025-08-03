{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../secrets/deployment.nix
  ];
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };
}
