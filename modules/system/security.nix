{
  config,
  lib,
  pkgs,
  machineType ? "",
  ...
}: let
  primaryUsername = config.primaryUser.name;

  # ─── Shared AppArmor deny rules ──────────────────────────────────────
  # `deny` wins over `allow` when both match the same path, so these
  # blocks turn a permissive `/** rwlkmix,` allow into a blocklist.
  #
  # Block 1: things no application ever has a legitimate reason to read.
  # Credentials, ragenix secrets, NAS/HAOS mounts, /etc/shadow, the
  # NixOS source tree (contains SSH pubkeys, hostnames, MQTT URLs).
  apparmorDenySecrets = ''
    deny @{HOME}/.ssh/** rwx,
    deny @{HOME}/.ssh/ rwx,
    deny @{HOME}/.gnupg/** rwx,
    deny @{HOME}/.gnupg/ rwx,
    deny @{HOME}/.config/git/** rwx,
    deny @{HOME}/.gitconfig rwx,
    deny @{HOME}/.config/1Password/** rwx,
    deny @{HOME}/.local/share/1Password/** rwx,
    deny @{HOME}/.local/share/kwalletd/** rwx,
    deny @{HOME}/.local/share/keyrings/** rwx,
    deny @{HOME}/Documents/nixos-config/secrets/** rwx,
    deny /run/agenix/** rwx,
    deny /run/agenix.d/** rwx,
    deny /mnt/** rwx,
    deny /etc/shadow rwx,
    deny /etc/nixos/** rwx,
  '';

  # Block 2: other browsers' profile dirs. Skipped in google-chrome's
  # own profile (it obviously needs to read its own data).
  apparmorDenyOtherBrowsers = ''
    deny @{HOME}/.config/chromium/** rwx,
    deny @{HOME}/.config/BraveSoftware/** rwx,
    deny @{HOME}/.config/vivaldi/** rwx,
    deny @{HOME}/.config/microsoft-edge/** rwx,
    deny @{HOME}/.mozilla/** rwx,
  '';

  # Block 3: Chrome's session/cookies/login-data dir. Used by every
  # profile EXCEPT chrome itself (cookie-theft is the main attack we
  # care about — games or random Electron apps reading Chrome's DB).
  apparmorDenyChrome = ''
    deny @{HOME}/.config/google-chrome/** rwx,
    deny @{HOME}/.cache/google-chrome/** rwx,
  '';

  # The permissive allow base. Anything not explicitly denied above is
  # allowed: full filesystem, network, capabilities, IPC, mounts.
  # Profiles using this become "blocklist" rather than "allowlist".
  apparmorPermissiveBase = ''
    /** rwlkmix,
    / rwlkmix,

    network,
    capability,
    signal,
    unix,
    dbus,
    mount,
    umount,
    pivot_root,
    ptrace,
    change_profile,
    userns,
    mqueue,
    io_uring,
  '';
in {
  boot = {
    blacklistedKernelModules = [
      # Obscure network protocols
      "ax25"
      "netrom"
      "rose"
      # Obscure filesystems
      "adfs"
      "affs"
      "bfs"
      "befs"
      "cramfs"
      "efs"
      "exofs"
      "freevxfs"
      "gfs2"
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
      # Network/Other
      "ksmbd"
      "tipc"
      "sctp"
      "dccp"
      "rds"
    ];
    kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.yama.ptrace_scope" = 2;
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
      "kernel.ftrace_enabled" = 0;
      # Block kexec — stops loading a replacement kernel at runtime, closing a
      # path that bypasses Secure Boot / signed-kernel guarantees. One-way latch.
      "kernel.kexec_load_disabled" = 1;
      # Deny unprivileged access to perf_event_open (kernel-info leak / attack
      # surface). Level 3 is the hardened-kernel max; treated as 2 on mainline.
      "kernel.perf_event_paranoid" = 3;
      # ── Network hardening (IPv4; IPv6 is disabled below) ──────────────
      # Reverse-path filtering: drop spoofed source addresses.
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      # Ignore ICMP redirects — a MITM can't reroute our traffic.
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      # We are not a router — never send ICMP redirects.
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      # Reject source-routed packets (classic spoofing vector).
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      # Disable IPv6 per-interface rather than ipv6.disable=1 — the kernel
      # param removes AF_INET6 entirely, breaking services that bind [::] (e.g. periphery, dhcpcd)
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
    };
    kernelParams = lib.mkAfter [
      "audit_backlog_wait_time=0" # Drop events instead of blocking when hold queue full
    ];
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
      cleanOnBoot = true;
    };
  };
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
  security = {
    audit = {
      enable = true;
      backlogLimit = 8192;
      rateLimit = 200;
      rules = [
        # Exclude high-volume low-value message types to prevent kauditd queue overflow
        "-a always,exclude -F msgtype=SERVICE_START"
        "-a always,exclude -F msgtype=SERVICE_STOP"
        "-a always,exclude -F msgtype=BPF"
        "-a always,exclude -F msgtype=PROCTITLE"
        "-a always,exclude -F msgtype=CWD"
        # Docker generates these constantly (iptables/netfilter changes, network setup)
        "-a always,exclude -F msgtype=NETFILTER_CFG"
        "-a always,exclude -F msgtype=NETFILTER_PKT"
        "-a always,exclude -F msgtype=PATH"

        # AppArmor configuration changes
        "-a always,exit -F arch=b64 -S openat,openat2 -F dir=/etc/apparmor.d/ -F perm=wa -F key=apparmor_changes"
        "-a always,exit -F arch=b32 -S openat,openat2 -F dir=/etc/apparmor.d/ -F perm=wa -F key=apparmor_changes"

        # Kernel module loading
        "-a always,exit -F arch=b64 -S init_module,finit_module -F key=module_insertion"
        "-a always,exit -F arch=b32 -S init_module,finit_module -F key=module_insertion"

        # Privilege escalation monitoring
        "-a always,exit -F arch=b64 -S execve -C auid!=euid -F auid!=unset -F euid=0 -F key=privesc_execve"
        "-a always,exit -F arch=b32 -S execve -C auid!=euid -F auid!=unset -F euid=0 -F key=privesc_execve"

        # NixOS configuration changes. This is a flake setup — the real config
        # lives in the user's repo, not /etc/nixos (which stays empty here), so
        # watch the repo path. /etc/nixos is kept too: it costs nothing and
        # still catches any legacy/out-of-band write there. The repo watch is a
        # no-op on hosts where it isn't checked out (e.g. r230); the rule loader
        # tolerates a failing watch per its `|| true` workaround below.
        "-a always,exit -F arch=b64 -S openat,openat2 -F dir=/etc/nixos/ -F perm=wa -F key=nixos-config"
        "-a always,exit -F arch=b32 -S openat,openat2 -F dir=/etc/nixos/ -F perm=wa -F key=nixos-config"
        "-a always,exit -F arch=b64 -S openat,openat2 -F dir=${config.users.users.${primaryUsername}.home}/Documents/nixos-config/ -F perm=wa -F key=nixos-config"
        "-a always,exit -F arch=b32 -S openat,openat2 -F dir=${config.users.users.${primaryUsername}.home}/Documents/nixos-config/ -F perm=wa -F key=nixos-config"

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
    };
    auditd.enable = true;
    apparmor = {
      enable = true;
      killUnconfinedConfinables = false;
      packages = with pkgs; [apparmor-utils apparmor-profiles];
      policies = {
        # ── Deny-only permissive profiles ────────────────────────────
        # These all use the same pattern:
        #   1. allow practically everything (`/** rwlkmix`, full network,
        #      capabilities, IPC, mounts) so we don't break the app
        #   2. explicitly `deny` paths the app never needs — credentials,
        #      ragenix secrets, server mounts, browser session data,
        #      /etc/shadow, the NixOS source tree
        # Safe to start in `enforce` because we're not introducing any
        # restriction the app was already hitting; we're only blocking
        # paths it had no business reading in the first place.
        #
        # Allowed `change_profile` so chrome-sandbox / electron sandbox
        # can transition renderers — no child profiles defined yet, but
        # the rule has to be present to permit the syscall.

        # Google Chrome — keep access to its own ~/.config/google-chrome
        "google-chrome" = {
          state = "enforce";
          profile = ''
            abi <abi/4.0>,
            include <tunables/global>
            ${lib.getBin pkgs.google-chrome}/share/google/chrome/google-chrome flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
            }
          '';
        };

        # Electron apps via pkgs.electron (Signal-desktop, etc.) —
        # deny google-chrome's session data as well as other browsers.
        "electron-common" = {
          state = "enforce";
          profile = ''
            abi <abi/4.0>,
            include <tunables/global>
            /nix/store/*-electron-unwrapped-*/libexec/electron/electron flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }
          '';
        };

        # Discord — bundles its own Electron at opt/Discord/.Discord-wrapped
        "discord" = {
          state = "enforce";
          profile = ''
            abi <abi/4.0>,
            include <tunables/global>
            /nix/store/*-discord-*/opt/Discord/.Discord-wrapped flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }
          '';
        };

        # Games — Steam, Lutris, Wine (incl. Proton via ix-inherit),
        # gamescope, Heroic. Anti-cheat (EAC / BattlEye on Linux) checks
        # ptrace_scope and /proc tampering, not AppArmor state, so a
        # deny-only profile is safe to enforce here. Steam Runtime uses
        # bubblewrap which needs `mount`/`pivot_root` — both granted in
        # the permissive base.
        #
        # `ix` on `/** rwlkmix` makes child processes (Proton, game .exe
        # under Wine, Steam Runtime helpers) inherit this profile, so we
        # don't need to enumerate every game binary.
        "games" = {
          state = "enforce";
          profile = ''
            abi <abi/4.0>,
            include <tunables/global>

            profile games-steam /nix/store/*-steam-*/bin/steam flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-lutris /nix/store/*-lutris-*/bin/lutris flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-wine /nix/store/*-wine-*/bin/wine flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-wine64 /nix/store/*-wine-*/bin/wine64 flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-wineserver /nix/store/*-wine-*/bin/wineserver flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-gamescope /nix/store/*-gamescope-*/bin/gamescope flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
            }

            profile games-heroic /nix/store/*-heroic-unwrapped-*/bin/heroic flags=(enforce) {
              ${apparmorPermissiveBase}
              ${apparmorDenySecrets}
              ${apparmorDenyOtherBrowsers}
              ${apparmorDenyChrome}
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
              /var/lib/quarantine/ rw,
              /var/lib/quarantine/** rw,
              /var/log/clamav/** rw,
              /run/clamav/** rw,
              /etc/clamav/** r,

              # Read access for scanning. `/ r,` is required separately —
              # `/** r,` does not match the root directory itself, and clamonacc
              # opens an FD on / to anchor *at() syscalls during quarantine moves.
              / r,
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
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        {
          users = [primaryUsername];
          persist = true;
          keepEnv = true;
        }
      ];
    };
  };
  # Firejail for ad-hoc sandboxing (e.g., firejail --private ./untrusted-binary)
  # No wrapped binaries - AppArmor handles everyday apps
  programs.firejail.enable = true;
  systemd = {
    # Allow wheel group to read audit logs
    tmpfiles.rules = [
      "d /var/log/audit 0750 root wheel - -"
      "f /var/log/audit/audit.log 0640 root wheel - -"
      # lynis-scan writes --report-file here; without the dir the weekly
      # report is silently lost (the service redirects output to /dev/null).
      "d /var/log/lynis 0750 root wheel - -"
    ];
    user.services.apparmor-notify = {
      description = "AppArmor Desktop Notifications";
      enable = true;
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
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
    services = {
      # Run vulnix daily
      vulnix-scan = {
        script = "${lib.getExe pkgs.vulnix} --system --gc-roots --whitelist ${./vulnix-whitelist.toml} --verbose > /var/log/vulnix.log 2>&1";
        # vulnix's NVD cache defaults to ~/.cache; point it at the
        # systemd-provided CacheDirectory so ProtectHome can stay on.
        environment.XDG_CACHE_HOME = "/var/cache/vulnix";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Nice = 5;
          IOSchedulingClass = 2;
          IOSchedulingPriority = 6;
          # vulnix exit codes: 0 = clean, 1 = only whitelisted findings,
          # 2 = vulnerabilities found. All three are successful scans, not
          # service failures — the report lands in /var/log/vulnix.log.
          SuccessExitStatus = [0 1 2];
          # Sandbox: vulnix only reads the store + gc-roots and talks to the
          # NVD mirror. read-only /home (not full ProtectHome) because
          # --gc-roots follows result symlinks into user checkouts.
          CacheDirectory = "vulnix";
          ProtectSystem = "strict";
          ReadWritePaths = ["/var/log"];
          ProtectHome = "read-only";
          PrivateTmp = true;
          NoNewPrivileges = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          RestrictRealtime = true;
        };
        after = ["network-online.target"];
        wants = ["network-online.target"];
      };
      # Run lynis weekly
      lynis-scan = {
        script = "${lib.getExe pkgs.lynis} audit system --report-file /var/log/lynis/lynis-report.dat > /dev/null 2>&1";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          # Deliberately NOT filesystem/namespace-sandboxed: lynis audits the
          # real system state (mount options, /tmp perms, home dirs, ...), so
          # ProtectSystem/ProtectHome/PrivateTmp would make it audit the
          # sandbox instead. Only side-effect-free restrictions here.
          NoNewPrivileges = true;
          LockPersonality = true;
          RestrictRealtime = true;
          ProtectClock = true;
        };
      };
      # Workaround for https://github.com/NixOS/nixpkgs/issues/483085
      # auditctl rejects some rules when AppArmor is enabled; load rule-by-rule
      # and tolerate individual failures so one bad rule doesn't fail the unit.
      audit-rules-nixos.serviceConfig.ExecStart = lib.mkForce [
        ""
        (pkgs.writeShellScript "load-audit-rules" ''
          ${lib.getExe' pkgs.audit "auditctl"} -D
          ${lib.getExe' pkgs.audit "auditctl"} -b ${toString config.security.audit.backlogLimit}
          ${lib.getExe' pkgs.audit "auditctl"} -f 1
          ${lib.getExe' pkgs.audit "auditctl"} -r ${toString config.security.audit.rateLimit}
          ${lib.concatMapStringsSep "\n" (
              rule: "${lib.getExe' pkgs.audit "auditctl"} ${rule} || true"
            )
            config.security.audit.rules}
          ${lib.getExe' pkgs.audit "auditctl"} -e 1
          exit 0
        '')
      ];
    };
    timers = {
      vulnix-scan = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
      lynis-scan = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "Weekly";
          Persistent = true;
        };
      };
    };
  };
}
