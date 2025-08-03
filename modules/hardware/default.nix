{ config, pkgs, ... }:
{
  imports = [
    ./amd_gpu
    ./logitech
    ./printers
  ];
}
