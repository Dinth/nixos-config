{ config, lib, pkgs, machineType ? "", ... }:
let
  primaryUsername = config.primaryUser.name;
in
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
    "kernel.yama.ptrace_scope" = 2;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.ftrace_enabled" = 0;
  };
  boot.kernelParams = [
    "ipv6.disable=1"
    "audit_backlog_limit=8192"    # Kernel-side backlog buffer
    "audit_backlog_wait_time=0"   # Drop events instead of blocking when hold queue full
  ];
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
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%";  # optional: limit size
    cleanOnBoot = true;  # optional: clean on boot
  };
  security.audit.enable = true;
  security.auditd.enable = false;
  security.audit.rules = [
    # Exclude high-volume low-value message types to prevent kauditd queue overflow
    "-a always,exclude -F msgtype=SERVICE_START"
    "-a always,exclude -F msgtype=SERVICE_STOP"
    "-a always,exclude -F msgtype=BPF"
    "-a always,exclude -F msgtype=PROCTITLE"
    "-a always,exclude -F msgtype=CWD"

    # AppArmor configuration changes
    "-a always,exit -F arch=b64 -S openat,openat2 -F dir=/etc/apparmor/ -F perm=wa -F key=apparmor_changes"
    "-a always,exit -F arch=b32 -S openat,openat2 -F dir=/etc/apparmor/ -F perm=wa -F key=apparmor_changes"
    "-a always,exit -F arch=b64 -S openat,openat2 -F dir=/etc/apparmor.d/ -F perm=wa -F key=apparmor_changes"
    "-a always,exit -F arch=b32 -S openat,openat2 -F dir=/etc/apparmor.d/ -F perm=wa -F key=apparmor_changes"

    # Kernel module loading
    "-a always,exit -F arch=b64 -S init_module,finit_module -F key=module_insertion"
    "-a always,exit -F arch=b32 -S init_module,finit_module -F key=module_insertion"

    # Privilege escalation monitoring
    "-a always,exit -F arch=b64 -S execve -C auid!=euid -F auid!=unset -F euid=0 -F key=privesc_execve"
    "-a always,exit -F arch=b32 -S execve -C auid!=euid -F auid!=unset -F euid=0 -F key=privesc_execve"

    # NixOS configuration changes
    "-a always,exit -F arch=b64 -S openat,openat2 -F dir=/etc/nixos/ -F perm=wa -F key=nixos-config"
    "-a always,exit -F arch=b32 -S openat,openat2 -F dir=/etc/nixos/ -F perm=wa -F key=nixos-config"

    # Identity files monitoring
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/passwd -F perm=wa -F key=identity"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/passwd -F perm=wa -F key=identity"
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/group -F perm=wa -F key=identity"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/group -F perm=wa -F key=identity"
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/shadow -F perm=wa -F key=identity"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/shadow -F perm=wa -F key=identity"

    # Privileged command execution
    "-a always,exit -F arch=b64 -S execve -F path=/run/wrappers/bin/doas -F key=privileged"
    "-a always,exit -F arch=b32 -S execve -F path=/run/wrappers/bin/doas -F key=privileged"

    # Network configuration changes
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/hosts -F perm=wa -F key=network_modifications"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/hosts -F perm=wa -F key=network_modifications"
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/resolv.conf -F perm=wa -F key=network_modifications"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/resolv.conf -F perm=wa -F key=network_modifications"

    # Privilege configuration changes
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/doas.conf -F perm=wa -F key=privileged_modifications"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/doas.conf -F perm=wa -F key=privileged_modifications"

    # SSH configuration changes
    "-a always,exit -F arch=b64 -S openat,openat2 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd_config"
    "-a always,exit -F arch=b32 -S openat,openat2 -F path=/etc/ssh/sshd_config -F perm=wa -F key=sshd_config"
  ];
  # Allow wheel group to read audit logs
  systemd.tmpfiles.rules = [
    "d /var/log/audit 0750 root wheel - -"
    "f /var/log/audit/audit.log 0640 root wheel - -"
  ];
  systemd.user.services.apparmor-notify = {
    description = "AppArmor Desktop Notifications";
    enable = true;

    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    unitConfig.ConditionPathExists = "/var/log/audit/audit.log";

    serviceConfig = {
      # -p: poll mode
      # -s 1: show summary
      # -w 5: wait 5 seconds (to group bursts of notifications)
      ExecStart = "${pkgs.apparmor-utils}/bin/aa-notify -p -s 1 -w 5 -f /var/log/audit/audit.log";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;
    packages = with pkgs; [ apparmor-utils apparmor-profiles ];
    policies = {
      # Google Chrome - web browser
      "google-chrome" = {
        state = "enforce";
        profile = ''
          abi <abi/4.0>,
          include <tunables/global>
          ${lib.getBin pkgs.google-chrome}/bin/.google-chrome-stable-wrapped flags=(enforce) {
            include <abstractions/base>
            include <abstractions/audio>
            include <abstractions/dbus-session-strict>
            include <abstractions/fonts>
            include <abstractions/freedesktop.org>
            include <abstractions/gnome>
            include <abstractions/mesa>
            include <abstractions/nameservice>
            include <abstractions/ssl_certs>
            include <abstractions/user-download>
            include <abstractions/vulkan>
            include <abstractions/X>

            capability sys_admin,
            capability sys_chroot,
            capability sys_ptrace,

            network inet stream,
            network inet6 stream,
            network inet dgram,
            network inet6 dgram,
            network netlink raw,

            /nix/store/** r,
            /nix/store/*/lib/** mr,
            /nix/store/*/bin/** rix,

            owner @{HOME}/.config/google-chrome/** rwk,
            owner @{HOME}/.cache/google-chrome/** rwk,
            owner @{HOME}/Downloads/** rw,

            /dev/ r,
            /dev/shm/** rw,
            /dev/dri/** rw,
            /sys/devices/** r,
            /proc/@{pid}/** r,
            /etc/machine-id r,
            /run/user/@{uid}/** rw,

            deny @{HOME}/.ssh/** rwx,
            deny @{HOME}/.gnupg/** rwx,
            deny @{HOME}/.config/git/** rwx,
            deny /etc/shadow r,
          }
        '';
      };

      # Electron apps (Discord, Slack, VSCode, etc.) - common attack vector
      "electron-common" = {
        state = "complain"; # Complain mode - Electron apps vary widely
        profile = ''
          abi <abi/4.0>,
          include <tunables/global>
          /nix/store/*-electron-*/lib/electron/electron flags=(complain) {
            include <abstractions/base>
            include <abstractions/audio>
            include <abstractions/fonts>
            include <abstractions/freedesktop.org>
            include <abstractions/mesa>
            include <abstractions/nameservice>
            include <abstractions/ssl_certs>
            include <abstractions/X>

            network inet stream,
            network inet6 stream,

            /nix/store/** r,
            /nix/store/*/lib/** mr,

            owner @{HOME}/.config/** rwk,
            owner @{HOME}/.cache/** rwk,
            owner @{HOME}/Downloads/** rw,

            /dev/shm/** rw,
            /dev/dri/** rw,
            /proc/@{pid}/** r,
            /run/user/@{uid}/** rw,

            deny @{HOME}/.ssh/** rwx,
            deny @{HOME}/.gnupg/** rwx,
          }
        '';
      };

      # clamonacc - runs as root, should be restricted
      # attach_disconnected is required for fanotify-based scanning
      "clamav-clamonacc" = {
        state = "enforce";
        profile = ''
          abi <abi/4.0>,
          include <tunables/global>
          ${lib.getBin pkgs.clamav}/bin/clamonacc flags=(attach_disconnected) {
            include <abstractions/base>
            include <abstractions/nameservice>

            capability sys_admin,      # fanotify
            capability dac_read_search, # read all files

            /nix/store/** r,
            /nix/store/*/lib/** mr,
            /nix/store/*/bin/** rix,

            # ClamAV operational paths
            /var/lib/clamav/** r,
            /var/lib/quarantine/** rw,
            /var/log/clamav/** rw,
            /run/clamav/** rw,
            /etc/clamav/** r,

            # Read access for scanning
            /** r,

            # Deny sensitive modifications
            deny /etc/** w,
            deny /boot/** w,
            deny /nix/** w,
          }
        '';
      };
    };
  };
  # Firejail for ad-hoc sandboxing (e.g., firejail --private ./untrusted-binary)
  # No wrapped binaries - AppArmor handles everyday apps
  programs.firejail.enable = true;
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      {
        users = [primaryUsername];
        persist = true;
        keepEnv = true;
      }
    ];
  };
  # Run vulnix daily
  systemd.services.vulnix-scan = {
    script = "${lib.getExe pkgs.vulnix} --system --gc-roots --verbose > /var/log/vulnix.log";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Nice = 5;
      IOSchedulingClass = 2;
      IOSchedulingPriority = 6;
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
  # Workaround for https://github.com/NixOS/nixpkgs/issues/483085
  systemd.services.audit-rules-nixos.serviceConfig.ExecStart = lib.mkForce [
    ""
    (pkgs.writeShellScript "load-audit-rules" ''

      ${pkgs.audit}/bin/auditctl -D

      ${lib.concatMapStringsSep "\n" (rule:
        "${pkgs.audit}/bin/auditctl ${rule}"
      ) config.security.audit.rules}

      ${pkgs.audit}/bin/auditctl -e 1 || true

      exit 0
    '')
  ];
}
