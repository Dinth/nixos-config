{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    hardware.steam-hardware.enable = true;
    programs.steam.enable = true;
  };
}
