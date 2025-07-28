{ config, pkgs, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    mc
    wget
    cifs-utils
    vim
    google-chrome
    yubioath-flutter
    vlc
    libvlc
    pciutils
    usbutils
    psmisc
    iotop
    iftop #
    ffmpeg # multimedia framework
    libfido2 # FIDO2 library (for Yubikeys)
    hdparm
    amdgpu_top # AMD graphic card resource monitor
    lm_sensors
    jq # JSON processor
    btop # system monitor and process viewer
    btop-rocm
    detach
    tabiew
    vivid
    difftastic # structural diff tool
    kdePackages.korganizer
    kdePackages.kontact
    kdePackages.kio-extras
    kdePackages.kio-fuse
    kdePackages.dolphin-plugins
    kdePackages.ktorrent
    kdePackages.kdepim-addons
    kdePackages.kompare
    kdePackages.kaccounts-providers
    kdePackages.kaccounts-integration
    kdePackages.skanlite
    kdePackages.phonon-vlc
    kdePackages.ksshaskpass
    kdePackages.ark
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.qtimageformats
    kdePackages.ffmpegthumbs
    haruna
    hwinfo
    inxi
    yubikey-manager # Yubikey manager
    ragenix
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
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  programs.usbtop.enable = true;

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.host.enableKvm = true;
  virtualisation.virtualbox.host.addNetworkInterface = false;

  programs.ssh.startAgent = true;
}
