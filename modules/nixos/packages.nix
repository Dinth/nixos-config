{ config, pkgs, lib, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    cifs-utils
    vlc
    libvlc
    pciutils
    usbutils
    psmisc
    ffmpeg # multimedia framework
    hdparm
    lm_sensors
    detach
    tabiew
    ragenix
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.en-science
    aspellDicts.pl
    _7zz
    python3

    nixos-anywhere
  ];




}
