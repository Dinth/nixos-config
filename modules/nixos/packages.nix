{ config, pkgs, lib, ... }:
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
    difftastic # structural diff
    lynis # vulnerability scanner
    chkrootkit # rootkit scanner
    clamav # AV scanner
#    aide
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
    git
    _7zz
    python3
    doas-sudo-shim
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
        ${lib.getExe pkgs.bash} -c " \
          while true; do \
            # Wait until a VM is running \
            while ! ${lib.getExe' pkgs.virtualbox "VBoxManage"} list runningvms | ${lib.getExe pkgs.gnugrep}/bin/grep -q '.'; do \
              sleep 30; \
            done; \
            \
            echo 'VM detected. Acquiring suspend lock.'; \
            \
            # Inhibit suspend while VMs are active. The lock is held for the duration of this command. \
            ${lib.getExe' pkgs.systemd "systemd-inhibit"} --what=sleep --who='VirtualBox' --why='A Virtual Machine is running' \
            ${lib.getExe pkgs.bash} -c 'while ${lib.getExe' pkgs.virtualbox "VBoxManage"} list runningvms | ${lib.getExe pkgs.gnugrep} -q \".\"; do sleep 30; done'; \
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
  #security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      {
        users = ["michal"];
        # persist = true;
        # noPass = true;
        keepEnv = true;
        # cmd = "ALL";
      }
    ];
  };
}
