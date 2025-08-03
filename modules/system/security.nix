{ config, lib, pkgs, ... }:
{
  security.sudo.enable = false;
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
}
