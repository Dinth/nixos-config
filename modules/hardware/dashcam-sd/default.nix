{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.dashcam-sd;
  primaryUsername = config.primaryUser.name;
  primaryUid = config.users.users.${primaryUsername}.uid;

  # udisks2 mounts removable media under here, naming the mountpoint after the
  # volume label (e.g. CAM) or, when the dashcam reformats the card and drops
  # the label, after the FS UUID (e.g. 18D8-8389). So we must NOT hardcode the
  # label-based path — we watch the media root and detect the card by its
  # distinctive directory structure instead.
  mediaRoot = "/run/media/${primaryUsername}";

  backupScript = pkgs.writeShellScript "dashcam-backup" ''
    set -euo pipefail

    MEDIA_ROOT="${mediaRoot}"
    TARGET="/home/${primaryUsername}/Documents/Dashcam/"

    mkdir -p "$TARGET"

    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${toString primaryUid}/bus"
    notify() {
      ${pkgs.libnotify}/bin/notify-send -a "Dashcam Backup" "$1" "$2"
    }

    # Scan every mounted removable volume for the dashcam's locked-clip folder.
    # Matching on structure (DCIM/Movie/RO) makes this independent of the volume
    # label, which the camera loses/changes on each reformat.
    shopt -s nullglob
    found=0
    total_new=0
    for card in "$MEDIA_ROOT"/*/; do
      src="''${card}DCIM/Movie/RO/"
      [ -d "$src" ] || continue
      found=1

      count_before=$(find "$TARGET" -type f 2>/dev/null | wc -l)
      ${lib.getExe pkgs.rsync} -av --ignore-existing "$src" "$TARGET"
      count_after=$(find "$TARGET" -type f | wc -l)
      total_new=$((total_new + count_after - count_before))
    done

    # No dashcam card present (path unit also fires for other removable media).
    [ "$found" -eq 1 ] || exit 0

    if [ "$total_new" -gt 0 ]; then
      notify "Backup Complete" "$total_new new files synced to ~/Documents/Dashcam"
    else
      notify "Backup Complete" "No new files to sync"
    fi
  '';
in {
  options = {
    dashcam-sd = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable automatic dashcam SD card backup";
      };
    };
  };

  config = mkIf cfg.enable {
    # Watch the media root rather than a label-specific path; udisks2 mounts
    # don't create system-level .mount units, so a systemd.path watching for
    # new entries under the media root is the reliable trigger. PathModified
    # fires whenever a volume is mounted/unmounted here, even when other
    # removable drives are already present.
    systemd.paths.dashcam-backup = {
      description = "Watch for dashcam SD card mount";
      wantedBy = ["multi-user.target"];
      pathConfig = {
        PathModified = mediaRoot;
        Unit = "dashcam-backup.service";
      };
    };

    systemd.services.dashcam-backup = {
      description = "Backup dashcam footage from SD card";

      serviceConfig = {
        Type = "oneshot";
        User = primaryUsername;
        ExecStart = backupScript;
        # Large card syncs are background work — keep them off the critical path
        # so the desktop stays responsive while footage copies.
        IOSchedulingClass = "idle";
        Nice = 19;
      };
    };
  };
}
