{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./amd_gpu
    ./brio4k
    ./dashcam-sd
    ./eizo
    ./logitech
    ./ntfs
    ./printers
    ./yubikey
  ];
}
