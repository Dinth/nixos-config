{ config, pkgs, ... }:
{
  imports = [
    ./komodo-periphery
    ./ssh
    ./tailscale
  ];
}
