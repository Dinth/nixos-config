{ config, lib, pkgs, machineType ? "", ... }:
{
  boot.blacklistedKernelModules = [
    # Obscure network protocols
    "ax25" "netrom" "rose"
    # Obscure filesystems
    "adfs" "affs" "bfs" "befs" "cramfs" "efs" "exofs" "freevxfs"
    "gfs2" "hfs" "hpfs" "jfs" "minix" "nilfs2" "omfs" "qnx4" "qnx6"
    "sysv" "ufs"
    # Network/Other
    "ksmbd" "tipc" "sctp" "dccp" "rds"
  ];
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1; # Use 2 for strict 'admin-only' attach
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
  };
  boot.kernelParams = [ "ipv6.disable=1" ];
  environment.systemPackages = with pkgs; [
    doas-sudo-shim
    lynis # vulnerability scanner
    clamav # AV scanner
    vulnix # Nix derivations vulnerability scanner
#    aide
  ];
  services.journald.extraConfig = ''
    SystemMaxFileSize=200M
    SystemMaxUse=2G
    MaxFileSec=1day
    MaxRetentionSec=7day
  '';
  boot.tmp.useTmpfs = true;
  security.audit.enable = true;
  security.auditd.enable = true;
  security.apparmor = {
    enable = true;
    packages = with pkgs; [ apparmor-utils ];
  };
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      {
        users = ["michal"];
        persist = true;
        # noPass = true;
        keepEnv = true;
        # cmd = "ALL";
      }
    ];
  };
  # Run vulnix daily
  systemd.services.vulnix-scan = {
    script = "${lib.getExe pkgs.vulnix} --system > /var/log/vulnix.log";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  systemd.timers.vulnix-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Run lynis weekly
  systemd.services.lynis-scan = {
    script = "${lib.getExe pkgs.lynis} audit system --report-file /var/log/lynis/lynis-report.dat > /dev/null 2>&1";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  systemd.timers.lynis-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Weekly";
      Persistent = true;
    };
  };
}
