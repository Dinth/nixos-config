{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.kde;
in {
  config = mkIf cfg.enable {
    # KRDC — KDE remote desktop client (VNC + RDP). Installed on every KDE host.
    environment.systemPackages = [pkgs.kdePackages.krdc];
  };
}
