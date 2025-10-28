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
    };
  };
}
