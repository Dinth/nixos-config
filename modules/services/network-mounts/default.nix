{
  config,
  lib,
  pkgs,
  machineType ? "",
  ...
}: let
  inherit (lib) mkIf mkOption mkMerge;
  cfg = config.services.networkMounts;
  primaryUsername = config.primaryUser.name;
  primaryUid = toString config.users.users.${primaryUsername}.uid;
  primaryGid = toString config.users.groups.users.gid;

  isWorkstation = machineType == "desktop" || machineType == "tablet";

  cifsOptions = credPath: [
    "credentials=${credPath}"
    "rw"
    "noserverino"
    "actimeo=1"
    "noperm"
    "cache=none"
    "echo_interval=10"
    "uid=${primaryUid}"
    "gid=${primaryGid}"
    "_netdev"
    "nofail"
    "vers=3.0"
    "x-systemd.automount"
    "x-systemd.requires=network-online.target"
    "x-systemd.after=network-online.target"
    "x-systemd.idle-timeout=60"
    "x-systemd.mount-timeout=30s"
  ];

  sshfsArgs = mountPoint:
    lib.concatStringsSep " " [
      "${lib.getExe pkgs.sshfs} root@10.10.1.13:/ ${mountPoint}"
      "-o IdentityFile=${config.age.secrets.id-ed25519.path}"
      "-o IdentitiesOnly=yes"
      "-o reconnect"
      "-o ServerAliveInterval=15"
      "-o ServerAliveCountMax=3"
      "-o StrictHostKeyChecking=accept-new"
      "-o UserKnownHostsFile=%h/.ssh/known_hosts"
    ];
in {
  options.services.networkMounts = {
    enable = mkOption {
      type = lib.types.bool;
      default = isWorkstation;
      description = "Persistent network mounts (SMB + sshfs) at fixed paths. Defaults on for desktop/tablet.";
    };
    smb.vm = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mount //10.10.1.19/VM at /mnt/VM. Per-host opt-in.";
    };
    smb.haosConfig = mkOption {
      type = lib.types.bool;
      default = isWorkstation;
      description = "Mount //10.10.1.11/config at /mnt/haos-config.";
    };
    sftp.omv = mkOption {
      type = lib.types.bool;
      default = isWorkstation;
      description = "sshfs 10.10.1.13:/ at ~/mnt/omv.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [pkgs.cifs-utils];
    }
    (mkIf cfg.smb.vm {
      fileSystems."/mnt/VM" = {
        device = "//10.10.1.19/VM";
        fsType = "cifs";
        options = cifsOptions "/run/agenix/nas-vm-creds";
      };
    })
    (mkIf cfg.smb.haosConfig {
      fileSystems."/mnt/haos-config" = {
        device = "//10.10.1.11/config";
        fsType = "cifs";
        options = cifsOptions "/run/agenix/smb-haos-creds";
      };
    })
    (mkIf cfg.sftp.omv {
      systemd.tmpfiles.rules = [
        "d /home/${primaryUsername}/mnt 0755 ${primaryUsername} users -"
        "d /home/${primaryUsername}/mnt/omv 0755 ${primaryUsername} users -"
      ];
      home-manager.users.${primaryUsername} = {
        home.packages = [pkgs.sshfs];
        systemd.user.services.sshfs-omv = {
          Unit = {
            Description = "sshfs: 10.10.1.13:/ -> %h/mnt/omv";
            After = ["network-online.target"];
            Wants = ["network-online.target"];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 3;
          };
          Service = {
            Type = "forking";
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/mnt/omv";
            ExecStart = sshfsArgs "%h/mnt/omv";
            ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/mnt/omv";
            Restart = "on-failure";
            RestartSec = 15;
          };
          Install.WantedBy = ["default.target"];
        };
      };
    })
  ]);
}
