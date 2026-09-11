{
  config,
  pkgs,
  lib,
  catppuccin,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common.nix
    ../../secrets/deployment.nix
  ];

  networking.hostName = "dinth-nixos-desktop"; # Define your hostname.
  networking.networkmanager.enable = true; # Enable networking via NM

  # Static wired address, declared here rather than left as an imperative NM
  # profile so it survives a reinstall and is reviewable in git.
  #
  # ensureProfiles renders these into /run/NetworkManager/system-connections,
  # while nmcli-created profiles live in /etc/NetworkManager/system-connections
  # and win on conflict. Any imperative profile for enp5s0 must therefore be
  # deleted (`nmcli con delete "Wired connection 2"`) for this one to take
  # effect.
  #
  # Keyfile syntax, not nmcli property syntax: the gateway is the second field
  # of address1, and dns is a semicolon-terminated list.
  networking.networkmanager.ensureProfiles.profiles = {
    wired-enp5s0 = {
      connection = {
        id = "wired-enp5s0";
        type = "802-3-ethernet";
        interface-name = "enp5s0";
        autoconnect = true;
      };
      ipv4 = {
        method = "manual";
        address1 = "10.40.0.10/24,10.40.0.1";
        dns = "10.10.1.12;";
      };
      ipv6 = {
        method = "auto";
        addr-gen-mode = "stable-privacy";
      };
    };
  };

  boot.plymouth.enable = true;

  cli.enable = true;
  graphical.enable = true;
  kde.enable = true;
  _1password.enable = true;
  gaming.enable = true;
  virtualisation.enable = true;
  logitech.enable = true;
  brio4k.enable = true;
  dashcam-sd.enable = true;
  printers.enable = true;
  weechat.enable = true;
  krdp.enable = true; # KDE RDP server sharing the live Plasma session (port 3389, LAN-only)
  docker.enable = false;
  yubikey.enable = true;
  agenticAi.enable = true;
  # Local inference stack: llama-server (Vulkan/RDNA2) on 127.0.0.1:8080,
  # SillyTavern on 127.0.0.1:8000 as its frontend. Both loopback-only; the
  # Ollama instance on omv stays where it is for everything else.
  llamaCpp.enable = true;
  sillytavern.enable = true;
  # Image generation for SillyTavern, same Vulkan story as llama-cpp. The
  # unit is gated on a checkpoint existing in ~/Models/sd, so it stays
  # dormant until one is downloaded.
  stableDiffusion.enable = true;
  # Three checkpoints, switched at runtime with `sd-switch <name>`. The active
  # one is a symlink seeded only when absent, so a switch is not undone by the
  # next rebuild. anime is the default: it is what the RP prompt prefixes
  # ("best quality, absurdres, masterpiece") are written for.
  stableDiffusion.checkpoints = {
    anime = "/home/michal/Models/sd/waiNSFWIllustrious_v14.safetensors";
    photo = "/home/michal/Models/sd/Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors";
    base = "/home/michal/Models/sd/model.safetensors";
  };
  stableDiffusion.defaultCheckpoint = "anime";
  # SDXL parks 6.6 GiB in VRAM, which the LLM also wants; --offload-to-cpu
  # keeps the weights in RAM (there is 62 GiB of it) and pulls them in only
  # while an image is actually being generated.
  stableDiffusion.extraFlags = ["--offload-to-cpu"];
  lnxlink.enable = true;
  lnxlink.mqtt.secretsFile = config.age.secrets.lnxlink-mqtt.path;
  services.networkMounts.smb.vm = true;
  # Prometheus exporters — node + systemd shared with r230; smartctl
  # additionally enabled here for real NVMe SMART data. The default
  # node_exporter hwmon collector picks up the it87 fan/temp sensors
  # from hardware-configuration.nix automatically.
  prometheus-exporters = {
    enable = true;
    scrapeAllowFrom = ["10.10.1.13"];
    smartctl.enable = true;
  };
  # Ship journald → omv Loki via Grafana Alloy.
  alloy.enable = true;
  # Wazuh agent → manager at edr.wickhay.uk.
  wazuh.enable = true;
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
    publicKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHw58iDAXminEmYKnzUjRzMhpR7rvULZZUZ0izMdiuhSAAAABHNzaDo="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIK+KGs2KSEQaHkzK+awc4QXMKu6kMn10F7cZ4raPcQJKAAAABHNzaDo="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMOPDiAQbAD53X2neUh/vbIv7pRx2+qkZ7Ti9PH+CJ1yAAAABHNzaDo="
    ];
  };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.primaryUser.name} = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = config.primaryUser.fullName;
    # Dropped: "network" + "vboxusers" — neither group exists (no module
    # creates them; VirtualBox is macOS-only here), so they only produced
    # activation warnings. "gamemode" stays — gaming.enable creates it here.
    extraGroups = ["networkmanager" "wheel" "scanner" "audio" "video" "dialout" "gamemode" "lp" "input"];
    openssh.authorizedKeys.keys = config.primaryUser.publicKeys;
  };
  home-manager.users.${config.primaryUser.name} = {
    imports = [catppuccin.homeModules.catppuccin];
    home = {
      stateVersion = "25.05";
      username = config.primaryUser.name;
      homeDirectory = "/home/${config.primaryUser.name}";
      packages = with pkgs; [
        mqtt-explorer
        discord
        signal-desktop
        caido-desktop
        milkytracker
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    ffmpeg # multimedia framework
    hdparm
    lm_sensors
    detach
    # nixos-anywhere removed — use `nix run nixpkgs#nixos-anywhere`
    # when bootstrapping a new host (used maybe once a year, no need
    # to keep its 267 MiB closure in every system generation).
  ];

  # dbus-broker is the default in nixos-26.05+; kept explicit for clarity.
  services.dbus.implementation = "broker";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
