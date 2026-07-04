{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption concatStringsSep mapAttrsToList;
  cfg = config.brio4k;

  # Render the configured V4L2 controls into `--set-ctrl a=1 --set-ctrl b=2`.
  setCtrlArgs = concatStringsSep " " (mapAttrsToList (k: v: "--set-ctrl ${k}=${toString v}") cfg.v4l2Controls);

  # Applied on every plug (udev → oneshot). Enumerates the Brio's capture nodes
  # by name and pushes the preferred controls; failures on the metadata node are
  # ignored. A short retry covers the window before the node settles.
  applyControls = pkgs.writeShellScript "brio4k-apply-controls" ''
    set -euo pipefail
    v4l2ctl=${lib.getExe' pkgs.v4l-utils "v4l2-ctl"}
    for attempt in 1 2 3 4 5; do
      nodes=$("$v4l2ctl" --list-devices 2>/dev/null \
        | ${lib.getExe pkgs.gnugrep} -A9 'Logitech BRIO' \
        | ${lib.getExe pkgs.gnugrep} -oE '/dev/video[0-9]+' || true)
      if [ -n "$nodes" ]; then
        for n in $nodes; do
          "$v4l2ctl" -d "$n" ${setCtrlArgs} >/dev/null 2>&1 || true
        done
        exit 0
      fi
      sleep 1
    done
  '';
in {
  options = {
    brio4k = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Logitech Brio 4K webcam support with V4L2 controls.";
      };
      v4l2Controls = mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.str);
        # 50 Hz mains (UK) removes LED/fluorescent flicker banding. Add e.g.
        # focus_automatic_continuous = 0; focus_absolute = 40; to lock focus.
        default = {power_line_frequency = 1;};
        description = "V4L2 controls to auto-apply to the Brio on every plug.";
      };
    };
  };

  config = mkIf cfg.enable {
    # V4L2 utilities for camera control
    environment.systemPackages = with pkgs; [
      v4l-utils # v4l2-ctl for command-line camera control
      cameractrls # GUI for webcam settings (supports Brio presets)
      ffmpeg # For camera testing/capture
    ];

    # UVC_QUIRK_FIX_BANDWIDTH (0x80): the Brio under-reports its bandwidth needs,
    # so uvcvideo rejects high-res/high-fps modes with -ENOSPC; this forces the
    # full alt-setting bandwidth. NOTE: modprobe options are module-global, so
    # this quirk applies to every UVC device on the system, not just the Brio.
    boot.extraModprobeConfig = ''
      options uvcvideo quirks=0x80
    '';

    # Ensure camera portal is available for applications
    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];

    # Permissions + trigger the control-apply service when the Brio appears.
    services.udev.extraRules = ''
      SUBSYSTEM=="video4linux", ATTR{name}=="Logitech BRIO", MODE="0660", GROUP="video", TAG+="uaccess", TAG+="systemd", ENV{SYSTEMD_WANTS}="brio4k-controls.service"
    '';

    systemd.services.brio4k-controls = {
      description = "Apply preferred V4L2 controls to the Logitech Brio 4K";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = applyControls;
      };
    };
  };
}
