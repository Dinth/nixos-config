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

  services.cron = {
    enable = true;
      systemCronJobs = [
        "00 2 * * 0 root ${lib.getExe' pkgs.chkrootkit "chkroot"} | grep --extended-regexp \"INFECTED|Warning\" | logger -t chkrootkit"
        "10 2 * * 0 root ${lib.getExe pkgs.lynis} audit system --cronjob > /dev/null 2>&1"
      ];
  };
  services.clamav = {
    daemon = {
      enable = true;
      settings = {
        OnAccessIncludePath = "/home";
        OnAccessPrevention = true;
        OnAccessExtraScanning = true;
        OnAccessExcludeUname = "clamav";
        User = "clamav";
      };
    };
    updater = {
      enable = true;
      interval = "daily";
      frequency = 1;
    };
    fangfrisch = {
      enable = true;
      interval = "daily";
    };
    scanner = {
      scanDirectories = [
        "/home"
        "/var/lib"
        "/tmp"
        "/etc"
        "/var/tmp"
      ];
      interval = "*-*-* 04:00:00";
    };
  };
  systemd.services."clamav-clamonacc" = {
    description = "ClamAV On-Access Scanner";
    documentation = ["man:clamonacc(8)" "man:clamd.conf(5)" "https://docs.clamav.net/"];
    requires = ["clamav-daemon.service"];
    after = ["clamav-daemon.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "root";
      ExecStartPre = ''${lib.getExe pkgs.bash} -c "while [ ! -S /run/clamav/clamd.ctl ]; do sleep 1; done"'';
      ExecStart = ''${lib.getExe' pkgs.clamav "clamonacc"} -F -c /etc/clamav/clamd.conf --move /root/quarantine  --fdpass --allmatch'';
      ExecReload = ''${lib.getExe' pkgs.coreutils "kill"} -USR2 $MAINPID'';
    };
  };
  users.groups.libvirtd.members = ["michal"];

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu = {
    swtpm.enable = true;
    ovmf.enable = true;
  };
  virtualisation.spiceUSBRedirection.enable = true;

}
