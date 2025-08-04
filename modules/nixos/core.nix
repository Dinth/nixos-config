{ config, pkgs, ... }:
{

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.initrd.systemd.enable = true;
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
  ];
  boot = {
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.max_map_count" = 524288; # 64GB ram,
      "vm.vfs_cache_pressure" = 50; # more memory for filesystem data
      "vm.dirty_ratio" = 30;
      "vm.dirty_background_ratio" = 15;
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
  };
  networking.hostName = "dinth-nixos-desktop"; # Define your hostname.


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.michal = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Michal";
    extraGroups = [ "networkmanager" "wheel" "scanner" "network" "disk" "audio" "video" "vboxusers" "dialout" "gamemode" ];
    packages = with pkgs; [
      discord
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
}
