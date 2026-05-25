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
      description = "sshfs root@10.10.1.13:/ at /mnt/omv.";
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
      fileSystems."/mnt/haos" = {
        device = "//10.10.1.11/config";
        fsType = "cifs";
        options = cifsOptions "/run/agenix/smb-haos-creds";
      };
    })
    (mkIf cfg.sftp.omv {
      system.fsPackages = [pkgs.sshfs];
      systemd.tmpfiles.rules = [
        "d /root/.ssh 0700 root root -"
      ];
      fileSystems."/mnt/omv" = {
        device = "root@10.10.1.13:/";
        fsType = "fuse.sshfs";
        options = [
          "ssh_command=${sshfsSshWrapper}"
          "IdentityFile=${config.age.secrets.id-ed25519.path}"
          "IdentitiesOnly=yes"
          "allow_other"
          "default_permissions"
          "uid=${primaryUid}"
          "gid=${primaryGid}"
          "reconnect"
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
      };
    })
  ]);
}
