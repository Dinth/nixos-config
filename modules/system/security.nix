{ config, lib, pkgs, machineType ? "", ... }:
{
  boot.blacklistedKernelModules = [
    # Obscure network protocols
    "ax25"
    "netrom"
    "rose"
    # Obscure/Legacy Filesystems
    "adfs"
    "affs"
    "bfs"
    "befs"
    "efs"
    "erofs"
    "exofs"
    "freevxfs"
    "f2fs"
    "vivid"
    "gfs2"
    "cramfs"
    "jffs2"
    "hfs"
    "hpfs"
    "jfs"
    "minix"
    "nilfs2"
    "omfs"
    "qnx4"
    "qnx6"
    "sysv"
    "ufs"
    "ksmbd"
    "tipc"
    "sctp"
    "dccp"
    "rds"
  ];
  services.journald.extraConfig = ''
    SystemMaxFileSize=200M
    SystemMaxUse=2G
    MaxFileSec=1day
    MaxRetentionSec=7day
  '';
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
  boot.kernelParams = [
    "kernel.kptr_restrict=2"
    "kernel.yama.ptrace_scope=1"
    "kernel.dmesg_restrict=1"
  ];
  environment.systemPackages = with pkgs; [
    doas-sudo-shim
    lynis # vulnerability scanner
    clamav # AV scanner
    vulnix # Nix derivations vulnerability scanner
#    aide
  ];
  services.cron = {
    enable = true;
      systemCronJobs = [
        "0 12 * * 3 root ${lib.getExe pkgs.vulnix} --system > /var/log/vulnix.log"
        "0 12 * * 2 root ${lib.getExe pkgs.lynis} audit system --cronjob --report-file /var/log/lynis/lynis-report.dat > /dev/null 2>&1"
      ];
  };
}
