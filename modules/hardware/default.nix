{ config, pkgs, ... }:
{
  imports = [
    ./amd_gpu
    ./eizo
    ./logitech
    ./printers
  ];
}
