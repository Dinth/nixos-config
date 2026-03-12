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
      earlySetup = false;  # Avoid conflict with Plymouth during initrd
      font = "ter-v18n";
      packages = [ pkgs.terminus_font ];
      useXkbConfig = true;
    };
    # Base layout for TTY (inherited via console.useXkbConfig)
    # Graphical options are managed in kde.nix via plasma-manager
    services.xserver.xkb = {
      layout = "pl";
      variant = "legacy";
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
