{ config, lib, pkgs,...}:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername} = {
      services.nextcloud-client = {
        enable = true;
        startInBackground = true;
      };
      # Delay startup to avoid race condition with Qt shared memory
      systemd.user.services.nextcloud-client.Service.ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
    };
  };
}
