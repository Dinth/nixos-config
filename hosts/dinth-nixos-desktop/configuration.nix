# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../secrets/deployment.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "dinth-nixos-desktop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "legacy";
    options = "terminate:ctrl_alt_bksp,kpdl:dot";
  };

  # Configure console keymap
  console.keyMap = "pl";


  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings.General.DisplayServer = "wayland";
    autoNumlock = true;
  };
  services.desktopManager.plasma6.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.hardware.bolt.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.steam-hardware.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.keyboard.qmk.enable = true;
  hardware.logitech = {
    wireless.enable = true;
    wireless.enableGraphical = true;
  };
  hardware.flipperzero.enable = true;
  # Enable CUPS to print documents.
  services.printing = {
  enable = true;
  drivers = with pkgs; [
    canon-cups-ufr2
  ];
  };
   hardware.printers = {
     ensurePrinters = [
       {
         name = "Canon_MF270_Series";
         location = "Wickhay";
         deviceUri = "socket://10.10.10.40:9100";
         model = "CNRCUPSMF270ZJ.ppd";
         ppdOptions = {
           PageSize = "A4";
         };
       }
     ];
     ensureDefaultPrinter = "Canon_MF270_Series";
   };
  hardware.sane.enable = true;
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.fwupd.enable = true;
  services.pcscd.enable = true;
  services.fstrim.enable = true;
  services.colord.enable = true;
  security.polkit.enable = true;
#  services.kdeconnect = {
#    enable = true;
#    indicator = true;
#  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.host.enableKvm = true;
  virtualisation.virtualbox.host.addNetworkInterface = false;
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.michal = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Michal";
    extraGroups = [ "networkmanager" "wheel" "scanner" "network" "disk" "audio" "video" "vboxusers" "dialout" "gamemode" ];
    packages = with pkgs; [
      discord
      orca-slicer
#       (bambu-studio.overrideAttrs {
#         version = "02.01.01.52";
#         buildInputs = oldAttrs.buildInputs ++ [ pkgs.boost188 ];
#         src = fetchFromGitHub {
#           owner = "bambulab";
#           repo = "BambuStudio";
#           rev = "v02.01.01.52";
#           hash = "sha256-AyHb2Gxa7sWxxZaktfy0YGhITr1RMqmXrdibds5akuQ=";
#         };
#       })
    ];
  };

  programs.ssh.startAgent = true;
#  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;
#  programs.gnupg.agent.enableSSHSupport = true;
#  programs.gnupg.agent.enable = true;

  programs._1password.enable = true;
  programs._1password-gui.enable = true;
  programs._1password-gui.polkitPolicyOwners = [ "michal" ];
  programs.kde-pim.kontact = true;
  programs.kdeconnect.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    localNetworkGameTransfers.openFirewall = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
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
  programs.gamemode.enable = true;
  programs.usbtop.enable = true;
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
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
    cifs-utils
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
    kdePackages.ktorrent
    kdePackages.ksshaskpass
    kdePackages.ark
    kdePackages.dolphin-plugins
    kdePackages.kio-extras
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

  environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken".source = config.age.secrets.chrome-enrolment.path;
  environment.etc."/opt/chrome/policies/enrollment/CloudManagementEnrollmentOptions".text = "Mandatory";

  systemd.services.logiops = {
    description = "An unofficial userspace driver for HID++ Logitech devices";
    # wantedBy = [ "graphical.target" ];
    # after = [ "bluetooth.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.logiops}/bin/logid";
    };
    restartTriggers = [ config.environment.etc."logid.cfg".source ];
  };
  environment.etc."logid.cfg".text = ''
  devices: ({
    name: "MX Master 3S";
    dpi: 1000;

    smartshift: {
      on: true;
      threshold: 12;
      default_threshold: 12;
    };

    hiresscroll: {
      hires: false;
      invert: false;
      target: true;
      up: {
            mode: "Axis";
            axis: "REL_WHEEL";
            axis_multiplier: 2.0;
      },
      down: {
              mode: "Axis";
              axis: "REL_WHEEL";
              axis_multiplier: -2.0;
      }
    };

    buttons: (
      {
        cid: 0xc3;
        action = {
          type: "Gestures";
          gestures: (
            {
              direction: "Up";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_UP"];
              };
            },
            {
              direction: "Down";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_DOWN"];
              };
            },
            {
              direction: "Left";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_LEFT"];
              };
            },
            {
              direction: "Right";
              mode: "OnRelease";
              action =
              {
                  type: "Keypress";
                  keys: ["KEY_LEFTMETA", "KEY_RIGHT"];
              };
            },
            {
              direction: "None";
              mode: "OnRelease";
              action = {
                type = "Keypress";
                keys: ["KEY_LEFTCTRL", "KEY_R"];
              };
            }
          );
        };
      }
    );
  });
  '';
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall = rec {
    enable = true;
    allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
    allowedUDPPortRanges = [{ from = 1714; to = 1764; }];
    allowedUDPPorts = [ 1900 2021 9999 ];
    allowedTCPPorts = [ 8883 9999 ];
    allowPing = true;
  };
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-lgc-plus
    noto-fonts-extra
    corefonts
    vista-fonts
    nerd-fonts.fira-code
  ];
  fonts.fontconfig = {
    enable = true;
    subpixel.rgba = "rgb";
    subpixel.lcdfilter = "light";
    hinting.style = "full";
    allowBitmaps = false;
  };
}
