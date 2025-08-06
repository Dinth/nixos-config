{ config, lib, pkgs, ... }:
{
  security.protectKernelImage = true;
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
    "uvcvideo"
    "tipc"
    "sctp"
    "dccp"
    "rds"
  ];
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    MaxFileSec=7day
  '';
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
  environment.systemPackages = with pkgs; [
    doas-sudo-shim
    lynis # vulnerability scanner
    chkrootkit # rootkit scanner
    clamav # AV scanner
#    aide
  ];
  services.cron = {
    enable = true;
      systemCronJobs = [
        "0 12 * * 1 root ${lib.getExe' pkgs.chkrootkit "chkroot"} | grep --extended-regexp \"INFECTED|Warning\" | logger -t chkrootkit"
        "0 12 * * 2 root ${lib.getExe pkgs.lynis} audit system --cronjob --report-file /var/log/lynis/lynis-report.dat > /dev/null 2>&1"
      ];
  };
}
