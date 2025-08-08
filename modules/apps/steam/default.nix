{ config, pkgs, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.gaming;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    hardware.steam-hardware.enable = true;
    programs.steam.enable = true;
    programs.gamemode.enable = true;
    environment.systemPackages = with pkgs; [
      mangohud
    ];

  };
}
