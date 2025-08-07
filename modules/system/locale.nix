{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
in
{
  config = mkIf pkgs.stdenv.isLinux {
    time.timeZone = "Europe/London";
    i18n.defaultLocale = "en_GB.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
    console = {
#      font = "Lat2-Terminus16";
# TODO: choose a console font
      useXkbConfig = true;
    };
    services.xserver.xkb = {
      layout = "pl";
      variant = "legacy";
      options = "terminate:ctrl_alt_bksp,kpdl:dot";
    };
    environment.systemPackages = with pkgs; [
      aspellDicts.en
      aspellDicts.en-computers
      aspellDicts.en-science
      aspellDicts.pl
      aspell
    ];
  };
}
