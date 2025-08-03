{ config, pkgs, ... }:
{
  imports = [
    ./system
    ./apps
  ];
}
