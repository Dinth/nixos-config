{ config, pkgs, ... }:
{
  imports = [
    ./amd_gpu
    ./brio4k
    ./eizo
    ./logitech
    ./printers
    ./yubikey
  ];
}
