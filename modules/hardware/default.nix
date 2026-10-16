{
  lib,
  isDarwin,
  ...
}: {
  imports =
    [
      ./yubikey
    ]
    # Linux-only: udev, kernel modules, sysfs and CUPS drivers. On macOS
    # printers come from Mosyle.
    ++ lib.optionals (!isDarwin) [
      ./amd_gpu
      ./brio4k
      ./dashcam-sd
      ./eizo
      ./logitech
      ./ntfs
      ./printers
    ];
}
