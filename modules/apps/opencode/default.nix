{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    home-manager.users.${primaryUsername}.programs.opencode = {
      enable = true;
    };
  };
}
