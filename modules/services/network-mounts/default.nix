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
  # uid is pinned via libs/users.nix; gid stays at the NixOS default for
  # normal users (100 = "users"). FUSE rejects an empty `uid=` value, so
  # the pin is load-bearing — don't switch back to the auto-assigned null.
  primaryUid = toString config.users.users.${primaryUsername}.uid;
  primaryGid = "100";

  isWorkstation = machineType == "desktop" || machineType == "tablet";

  # The id-ed25519 private key is passphrase-protected. For a system mount
  # there is no agent or wallet available, so we feed the passphrase to ssh
  # non-interactively via SSH_ASKPASS pointing at a script that cats the
  # ragenix-decrypted passphrase secret. SSH_ASKPASS_REQUIRE=force makes
  # OpenSSH (>=8.4) use askpass even without a TTY or DISPLAY.
  sshfsAskpass = pkgs.writeShellScript "sshfs-omv-askpass" ''
    exec ${pkgs.coreutils}/bin/cat ${config.age.secrets.id-ed25519-passphrase.path}
  '';
  sshfsSshWrapper = pkgs.writeShellScript "sshfs-omv-ssh" ''
    export SSH_ASKPASS=${sshfsAskpass}
    export SSH_ASKPASS_REQUIRE=force
    exec ${pkgs.openssh}/bin/ssh "$@"
  '';

  # Shared by both OMV subtree mounts below.
  sshfsOptions = [
    "ssh_command=${sshfsSshWrapper}"
    "IdentityFile=${config.age.secrets.id-ed25519.path}"
    "IdentitiesOnly=yes"
    "allow_other"
    "default_permissions"
    "uid=${primaryUid}"
    "gid=${primaryGid}"
    "reconnect"
    "workaround=rename"
    "ServerAliveInterval=15"
    "ServerAliveCountMax=3"
    "StrictHostKeyChecking=accept-new"
    "UserKnownHostsFile=/root/.ssh/known_hosts"
    "_netdev"
    "nofail"
    "x-systemd.automount"
    "x-systemd.requires=network-online.target"
    "x-systemd.after=network-online.target"
    "x-systemd.idle-timeout=300"
    "x-systemd.mount-timeout=30s"
  ];

  # vers=3.1.1: all servers here (OMV, HAOS Samba, 10.10.1.19) speak SMB
  # 3.1.1, which adds pre-auth integrity (downgrade protection) and
  # AES-128-GCM over the 3.0 we used before.
  #
  # cache: defaults to "strict" (kernel-managed oplock caching) for
  # throughput. The HAOS config share overrides to cache=none + sync so a
  # config edit is flushed to the HAOS disk before save returns, otherwise
  # HA reloads can miss freshly-written config.
  cifsOptions = {
    credPath,
    cache ? "strict",
    extra ? [],
  }:
    [
      "credentials=${credPath}"
      "rw"
      "noserverino"
      "actimeo=1"
      "noperm"
      "cache=${cache}"
      "echo_interval=10"
      "uid=${primaryUid}"
      "gid=${primaryGid}"
      "_netdev"
      "nofail"
      "vers=3.1.1"
      "x-systemd.automount"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=30s"
    ]
    ++ extra;
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
      description = "Mount //10.10.1.11/config at /mnt/haos.";
    };
    sftp.omv = mkOption {
      type = lib.types.bool;
      default = isWorkstation;
      description = "sshfs the OMV data subtrees (/Data, /opt/docker) under /mnt/omv.";
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
        options = cifsOptions {credPath = "/run/agenix/nas-vm-creds";};
      };
    })
    (mkIf cfg.smb.haosConfig {
      fileSystems."/mnt/haos" = {
        device = "//10.10.1.11/config";
        fsType = "cifs";
        options = cifsOptions {
          credPath = "/run/agenix/smb-haos-creds";
          cache = "none";
          extra = ["sync"];
        };
      };
    })
    (mkIf cfg.sftp.omv {
      system.fsPackages = [pkgs.sshfs];
      systemd.tmpfiles.rules = [
        "d /root/.ssh 0700 root root -"
      ];
      # Only the data subtrees, not the NAS root. Mounting root@omv:/ gave
      # any workstation compromise (or a stray rm -rf through the automount)
      # root-level write to the entire OMV system disk — /etc, /root, /var.
      # The mountpoints mirror the server paths under /mnt/omv so existing
      # /mnt/omv/Data and /mnt/omv/opt/docker references keep working.
      fileSystems."/mnt/omv/Data" = {
        device = "root@10.10.1.13:/Data";
        fsType = "fuse.sshfs";
        options = sshfsOptions;
      };
      fileSystems."/mnt/omv/opt/docker" = {
        device = "root@10.10.1.13:/opt/docker";
        fsType = "fuse.sshfs";
        options = sshfsOptions;
      };
    })
  ]);
}
