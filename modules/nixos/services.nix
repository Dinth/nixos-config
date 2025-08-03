{ config, pkgs, lib, ... }:
{
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
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

  users.groups.libvirtd.members = ["michal"];

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu = {
    swtpm.enable = true;
    ovmf.enable = true;
  };
  virtualisation.spiceUSBRedirection.enable = true;

}
