{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.dashcam-sd;
  primaryUsername = config.primaryUser.name;
  primaryUid = config.users.users.${primaryUsername}.uid;

  # Mount unit name for the SD card (udisks2 creates this)
  mountUnit = "run-media-${primaryUsername}-CAM.mount";

  backupScript = pkgs.writeShellScript "dashcam-backup" ''
    set -euo pipefail

    SOURCE="/run/media/${primaryUsername}/CAM/DCIM/Movie/RO/"
    TARGET="/home/${primaryUsername}/Documents/Dashcam/"

    # Create target if missing
    mkdir -p "$TARGET"

    # Count files before sync
    count_before=$(find "$TARGET" -type f 2>/dev/null | wc -l)

    # Rsync: archive mode, skip existing files
    ${lib.getExe pkgs.rsync} -av --ignore-existing "$SOURCE" "$TARGET"

    # Count files after sync
    count_after=$(find "$TARGET" -type f | wc -l)
    new_files=$((count_after - count_before))

    # Send desktop notification
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${toString primaryUid}/bus"
    if [ "$new_files" -gt 0 ]; then
      ${pkgs.libnotify}/bin/notify-send -a "Dashcam Backup" "Backup Complete" "$new_files new files synced to ~/Documents/Dashcam"
    else
      ${pkgs.libnotify}/bin/notify-send -a "Dashcam Backup" "Backup Complete" "No new files to sync"
    fi
  '';
in
{
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
    # System service that triggers when the CAM SD card is mounted
    systemd.services.dashcam-backup = {
      description = "Backup dashcam footage from SD card";
      after = [ mountUnit ];
      bindsTo = [ mountUnit ];
      wantedBy = [ mountUnit ];

      serviceConfig = {
        Type = "oneshot";
        User = primaryUsername;
        ExecStart = backupScript;
        # Give mount a moment to settle
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      };
    };
  };
}
