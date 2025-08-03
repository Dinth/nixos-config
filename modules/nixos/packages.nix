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
    doas-sudo-shim
    nixos-anywhere
  ];


  programs.htop = {
    enable = true;
    settings = {
      detailed_cpu_time = true;
      hide_kernel_threads = false;
      show_cpu_frequency = true;
      show_cpu_usage = true;
      show_program_path = false;
      show_thread_names = true;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.ssh.startAgent = true;
  #security.sudo.enable = false;
}
