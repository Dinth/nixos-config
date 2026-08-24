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

  # ssh_command must be referenced through a *stable* path, not the store path
  # of the wrapper. switch-to-configuration diffs /etc/fstab and reloads any
  # mount whose options string changed (switch-to-configuration-ng main.rs:1987
  # — unconditional, X-ReloadIfChanged is not consulted for fstab mounts).
  # Reloading a mount means `mount -o remount`, which FUSE rejects outright
  # ("fuse: unknown option(s): `-o remount'"), failing the whole activation.
  # The wrapper's store path rehashes on every openssh bump, so embedding it
  # directly broke activation on each such rebuild. /etc/sshfs-omv-ssh is a
  # symlink to the current wrapper, so the fstab line never changes.
  sshfsSshWrapperPath = "/etc/sshfs-omv-ssh";

  # Shared by both OMV subtree mounts below.
  sshfsOptions = [
    "ssh_command=${sshfsSshWrapperPath}"
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
  #
  # automount = false is for shares whose server is not always powered on.
  # An x-systemd.automount against an offline server is actively harmful: every
  # stat() into the mountpoint (Dolphin/KIO, zsh path completion, df,
  # node_exporter's filesystem collector) blocks for the full mount-timeout,
  # and the automount re-arms on each access so it never stops. Such a share
  # gets "noauto" and is started explicitly by whatever powers the server on.
  cifsOptions = {
    credPath,
    cache ? "strict",
    automount ? true,
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
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
      "x-systemd.mount-timeout=30s"
    ]
    ++ (
      if automount
      then [
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
      ]
      else ["noauto"]
    )
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
      # The QNAP at 10.10.1.19 is powered off except while the LinuxMint VM
      # runs — modules/system/virtualisation/nas-power-hook.sh wakes it on
      # domain prepare and shuts it down 600 s after release, starting and
      # stopping mnt-VM.mount around that window. So this must be noauto:
      # the hook already stops the automount before poweroff, but `systemctl
      # stop` is runtime-only and the fstab entry re-arms it on the next boot,
      # leaving the desktop stat()-blocking on a dead host until someone
      # notices. noauto keeps the unit startable by the hook without ever
      # arming an automount of its own.
      fileSystems."/mnt/VM" = {
        device = "//10.10.1.19/VM";
        fsType = "cifs";
        options = cifsOptions {
          credPath = "/run/agenix/nas-vm-creds";
          automount = false;
        };
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
      # Symlink into the store: the target rehashes on openssh bumps but this
      # path does not, keeping the fstab options stable (see sshfsSshWrapperPath).
      environment.etc."sshfs-omv-ssh".source = sshfsSshWrapper;
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
