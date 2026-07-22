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
    # NOTE: there is no `audit_backlog_wait_time` kernel command-line
    # parameter — the kernel only accepts `audit=` and `audit_backlog_limit=`
    # (both set for us by security.audit.{enable,backlogLimit}). Passing it
    # here got it logged as "Unknown kernel command line parameters" and
    # handed to userspace as an env var, leaving backlog_wait_time at its
    # 60000 (60s) default. It is set at runtime by the rule loader below.
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
  # Upstream nixpkgs bug: apparmor-utils declares pythonPath = [notify2 psutil
  # libapparmor] but omits tkinter, while aa-notify (4.1.x) imports
  # apparmor.gui unconditionally at import time — and apparmor/gui.py does
  # `import tkinter`. So aa-notify dies with ModuleNotFoundError: No module
  # named '_tkinter' before parsing a single argument. Applied as an overlay
  # rather than only in the unit's ExecStart so an interactive `aa-notify`
  # works too.
  nixpkgs.overlays = [
    (_final: prev: {
      apparmor-utils = prev.apparmor-utils.overrideAttrs (old: {
        pythonPath = (old.pythonPath or []) ++ [prev.python3Packages.tkinter];
      });
    })
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
      # Queue depth for records the kernel has generated but auditd has not
      # drained yet. 8192 was being overrun: `auditctl -s` reported a growing
      # `lost` counter and the kernel logged "audit: rate limit exceeded".
      backlogLimit = 32768;
      # Records/second ceiling, enforced by the kernel. This was 200, which is
      # below what this host actually produces (execve bursts during a
      # nixos-rebuild alone exceed it), so the kernel was silently dropping
      # audit records — holes in the log exactly when it matters most. 0 =
      # unlimited; overflow protection is backlogLimit plus the -f 1 below.
      rateLimit = 0;
      rules = [
        # ── Exclusions ────────────────────────────────────────────────
        # Standalone record types that are pure volume here. These work:
        # a post-fix `ausearch` over the log shows none of them landing.
        "-a always,exclude -F msgtype=SERVICE_START"
        "-a always,exclude -F msgtype=SERVICE_STOP"
        "-a always,exclude -F msgtype=BPF"
        # Docker generates these constantly (iptables/netfilter changes, network setup)
        "-a always,exclude -F msgtype=NETFILTER_CFG"
        "-a always,exclude -F msgtype=NETFILTER_PKT"
        # PROCTITLE stays excluded: it is a hex-encoded copy of the command
        # line attached to *every* syscall event, and for the execve rules
        # below the EXECVE record already carries argv.
        "-a always,exclude -F msgtype=PROCTITLE"
        #
        # PATH and CWD are deliberately NOT excluded. They used to be, which
        # quietly defeated every file rule in this list: PATH is the ancillary
        # record naming the file a syscall touched, and CWD resolves relative
        # paths. Without them a `-F dir=`/`-F path=` rule still fires, but the
        # resulting SYSCALL record says only "a write-open happened" with no
        # filename — the one fact the rule exists to capture. They are the
        # payload of a file watch, not overhead.

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
        # lives in the user's repo, so watch the repo path. /etc/nixos no longer
        # exists (a stale unstable-channel flake lived there and got picked up
        # by bare `nixos-rebuild`, which resolves it by default); watches on a
        # missing directory never load, so keeping them would be dead config
        # rather than a tripwire. The repo watch is a no-op on hosts where it
        # isn't checked out (e.g. r230); the rule loader tolerates a failing
        # watch per its `|| true` workaround below.
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
    auditd = {
      enable = true;
      # The NixOS module only defaults space_left/admin_space_left, and
      # auditd's own default is num_logs = 0, i.e. *no rotation at all*.
      # /var/log/audit/audit.log had therefore been growing as a single file
      # since January. Cap and rotate it.
      settings = {
        max_log_file = 64; # MiB per file
        max_log_file_action = "rotate";
        num_logs = 8; # → 512 MiB ceiling for the whole audit trail
        # Percentages, not the module's absolute-MiB defaults (75/50 MiB on a
        # 3.6T root means "warn once the disk is already full").
        space_left = "5%";
        space_left_action = "syslog";
        admin_space_left = "2%";
        admin_space_left_action = "syslog";
        # Default here is SUSPEND, which stops audit logging and needs a manual
        # restart. Rotate instead: losing the oldest log beats losing the newest.
        disk_full_action = "rotate";
        # auditd recreates audit.log on every rotation as root:root 0600,
        # which would undo the systemd.tmpfiles rules below (they only run at
        # boot) and break the user-session aa-notify that tails this file.
        log_group = "wheel";
      };
    };
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
    # Allow wheel group to read audit logs, so the user-session aa-notify can
    # tail them. These only run at boot and auditd rewrites the log's
    # ownership when it starts and on every rotation, so they are the
    # belt to `security.auditd.settings.log_group = "wheel"`'s braces.
    tmpfiles.rules = [
      "d /var/log/audit 0750 root wheel - -"
      "f /var/log/audit/audit.log 0640 root wheel - -"
      # lynis-scan writes --report-file here; without the dir the weekly
      # report is silently lost (the service redirects output to /dev/null).
      "d /var/log/lynis 0750 root wheel - -"
      # nixpkgs' apparmor module writes `profiledir = /var/cache/apparmor/logprof`
      # into logprof.conf, but nothing ever creates that directory —
      # /var/cache/apparmor is made by apparmor_parser as its 0700 root-only
      # cache-loc and has no logprof/ inside. The python tooling resolves
      # profiledir with find_first_dir(), which returns None for a missing or
      # unreadable path and then silently falls back to /etc/apparmor.d. On
      # NixOS that tree is an incomplete 38-entry closure (upstream ships 124),
      # so aa-notify's read_profiles() died on the first unresolvable include
      # — "tunables/global not found", then "abstractions/crypto not found".
      # Creating the directory makes profiledir resolve as intended. Empty is
      # correct: it only feeds can_allow_rule's "add this rule" suggestions,
      # which are meaningless against read-only store profiles anyway.
      # 0711 on the parent grants traverse without exposing the policy cache.
      "d /var/cache/apparmor 0711 root root - -"
      "d /var/cache/apparmor/logprof 0755 root root - -"
    ];
    user.services.apparmor-notify = {
      description = "AppArmor Desktop Notifications";
      enable = true;
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      # NB: no ConditionPathExists on the audit log. A user unit cannot order
      # itself after the system-level auditd.service, so the condition was
      # racing it — and a failed condition means "skip", evaluated once, with
      # no retry. That is exactly what happened: the log was unreadable to
      # this user at graphical-session time, the unit was skipped, and it then
      # sat inactive for the entire uptime. Restart=always below turns that
      # same situation into a retry loop that recovers on its own.
      unitConfig.StartLimitIntervalSec = 0; # never give up permanently
      serviceConfig = {
        # -p: poll mode
        # -s 1: show summary
        # -w 5: wait 5 seconds (to group bursts of notifications)
        ExecStart = "${pkgs.apparmor-utils}/bin/aa-notify -p -s 1 -w 5 -f /var/log/audit/audit.log";
        # aa-notify is a forking daemon: notify_about_new_entries() calls
        # os.fork() and the parent immediately os._exit(0), leaving the child
        # to tail the log. Under the default Type=simple systemd sees that
        # parent exit as the service ending — and since it also kills any
        # other running aa-notify by process name on startup, Restart would
        # have torn down and respawned the real daemon every RestartSec
        # forever, even with zero errors.
        Type = "forking";
        # `always`, not `on-failure`: aa-notify also exits 0 in cases we want
        # to recover from (log rotated out from under it, transient read
        # failure). It is a tailer — it should never stay stopped.
        Restart = "always";
        RestartSec = "10s";
      };
    };
    services = {
      # auditd only reads auditd.conf at startup, and nothing in the unit
      # references that file — so `nixos-rebuild switch` would install a new
      # /etc/audit/auditd.conf while leaving the running daemon on its old
      # in-memory settings indefinitely (observed: rotation and log_group
      # changes not taking effect against an auditd from a 4-day-old boot).
      #
      # This has to be a *reload*, not a restart: upstream's auditd.service
      # sets RefuseManualStop=yes, so systemd will not stop it and a
      # restartTrigger is silently a no-op. Upstream also ships no ExecReload,
      # so supply one — auditd re-reads its config on SIGHUP and records a
      # DAEMON_CONFIG event on success.
      auditd = {
        reloadTriggers = [config.environment.etc."audit/auditd.conf".source];
        serviceConfig.ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
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
          # Never let a full backlog block the syscall that generated the
          # record — a stalled auditd would otherwise freeze userspace for up
          # to 60s. This is the runtime equivalent of the kernel parameter
          # that does not exist (see boot.kernelParams above).
          ${lib.getExe' pkgs.audit "auditctl"} --backlog_wait_time 0
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
