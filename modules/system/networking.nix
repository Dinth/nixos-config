{ config, lib, pkgs, ... }:
let
  primaryUsername = config.primaryUser.name;
in
{
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
      MaxAuthTries = 3;
      MaxSessions = 10;
      AllowUsers = [ primaryUsername ];
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall = rec {
    enable = true;
    allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
    allowedUDPPortRanges = [{ from = 1714; to = 1764; }];
    allowedUDPPorts = [ 1900 2021 ];
    allowedTCPPorts = [ 8883 ];
    allowPing = true;
    logRefusedPackets = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
