{ config, pkgs, lib, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    logiops # Unofficial HID driver for Logitech devices
    cifs-utils
    yubioath-flutter
    vlc
    libvlc
    pciutils
    usbutils
    psmisc
    ffmpeg # multimedia framework
    libfido2 # FIDO2 library (for Yubikeys)
    hdparm
    lm_sensors
    detach
    tabiew
    vivid
    lynis # vulnerability scanner
    chkrootkit # rootkit scanner
    clamav # AV scanner
#    aide
    yubikey-manager # Yubikey manager
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

  programs._1password.enable = true;
  programs._1password-gui.enable = true;
  programs._1password-gui.polkitPolicyOwners = [ "michal" ];

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
  programs.usbtop.enable = true;

  programs.ssh.startAgent = true;
  #security.sudo.enable = false;
}
