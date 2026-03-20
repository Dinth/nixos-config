{ config, pkgs, ... }:
{
  imports = [
    ./amd_gpu
    ./brio4k
    ./dashcam-sd
    ./eizo
    ./logitech
    ./printers
    ./yubikey
  ];
}
