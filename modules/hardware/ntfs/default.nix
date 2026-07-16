{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.ntfs;
in {
  options = {
    ntfs = {
      enable = mkOption {
        type = lib.types.bool;
        # Every graphical host sees Windows disks and USB drives; the headless
        # r230 has no removable media, so it stays out of the closure.
        default = config.graphical.enable;
        description = "Enable NTFS read/write support (ntfs-3g driver + ntfsprogs tools).";
      };
    };
  };
  config = mkIf cfg.enable {
    # Pulls pkgs.ntfs3g into system.fsPackages, which installs the
    # /sbin/mount.ntfs helper that plain `mount`, fstab and udisks2 (Dolphin's
    # removable-media mounting) all dispatch to for fsType "ntfs". Without a
    # helper on PATH, mounting an NTFS volume fails outright — the in-kernel
    # ntfs3 driver is built but nothing selects it for type "ntfs".
    boot.supportedFilesystems.ntfs = true;

    # ntfs3g also ships ntfsprogs: ntfsfix (clear the dirty flag Windows leaves
    # behind after fast-startup/hibernate, which makes ntfs-3g refuse to mount
    # read-write), mkntfs, ntfsresize, ntfsclone, ntfslabel, ntfsinfo.
    environment.systemPackages = [pkgs.ntfs3g];
  };
}
