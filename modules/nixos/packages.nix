{ config, pkgs, ... }:
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    mc
    logiops # Unofficial HID driver for Logitech devices
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
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.en-science
    aspellDicts.pl
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
  systemd.user.services.virtualbox-suspend-inhibitor = {
    description = "Suspend Inhibitor for VirtualBox";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c " \
          while true; do \
            # Wait until a VM is running \
            while ! ${pkgs.virtualbox}/bin/VBoxManage list runningvms | ${pkgs.gnugrep}/bin/grep -q '.'; do \
              sleep 30; \
            done; \
            \
            echo 'VM detected. Acquiring suspend lock.'; \
            \
            # Inhibit suspend while VMs are active. The lock is held for the duration of this command. \
            ${pkgs.systemd}/bin/systemd-inhibit --what=sleep --who='VirtualBox' --why='A Virtual Machine is running' \
            ${pkgs.bash}/bin/bash -c 'while ${pkgs.virtualbox}/bin/VBoxManage list runningvms | ${pkgs.gnugrep}/bin/grep -q \".\"; do sleep 30; done'; \
            \
            echo 'Last VM shut down. Releasing suspend lock.'; \
          done \
        "
      '';
      Restart = "always";
      RestartSec = "10";
    };
  };
  programs.ssh.startAgent = true;
}
