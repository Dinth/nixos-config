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
    "kernel.yama.ptrace_scope" = 1; # Use 2 for strict 'admin-only' attach
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
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
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%";  # optional: limit size
    cleanOnBoot = true;  # optional: clean on boot
  };
  security.auditd.enable = true;
  security.audit.rules = [
    # --- Noise Reduction ---
    # Exclude systemd service start/stop - must be first
    "-A exclude,always -F msgtype=SERVICE_START"
    "-A exclude,always -F msgtype=SERVICE_STOP"
    # Exclude systemd eBPF usage - must be first
    "-A exclude,always -F msgtype=BPF"

    # --- AppArmor Profile Protection ---
    # Monitor changes to AppArmor profiles
    # -p wa = watch for writes and attribute changes
    # -k = tag with key for easy log filtering
    "-w /etc/apparmor/ -p wa -k apparmor_changes"
    "-w /etc/apparmor.d/ -p wa -k apparmor_changes"

    # --- Kernel Module Loading Detection ---
    # Log all kernel module insertions
    # init_module/finit_module = syscalls used by insmod/modprobe
    # Both 64-bit and 32-bit architectures covered for compatibility
    "-a exit,always -F arch=b64 -S init_module -S finit_module -k module_insertion"
    "-a exit,always -F arch=b32 -S init_module -S finit_module -k module_insertion"

    # --- Privilege Escalation Detection ---
    # Capture when processes execute as root but were started by different user
    # auid = original login user ID (doesn't change with sudo/doas)
    # euid = effective user ID (becomes 0 when elevated to root)
    # This logs all doas/sudo usage and potential exploit attempts
    # auid!=unset filters out system processes without login sessions
    "-a exit,always -F arch=b64 -C auid!=euid -F auid!=unset -F euid=0 -S execve -k privesc_execve"
    "-a exit,always -F arch=b32 -C auid!=euid -F auid!=unset -F euid=0 -S execve -k privesc_execve"

    # --- System Configuration Monitoring ---
    # Track changes to critical NixOS and identity management files
    "-w /etc/nixos/ -p wa -k nixos-config"
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/group -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"

    # --- Privileged Command Monitoring ---
    # Log execution of doas (your privilege escalation tool)
    "-w /run/wrappers/bin/doas -p x -k privileged"
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
    packages = with pkgs; [ apparmor-utils ];
  };
  programs.firejail = {
    enable = true;
    # TBD: Add jails
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
    script = "${lib.getExe pkgs.vulnix} --system --user ${primaryUsername} --verbose > /var/log/vulnix.log";
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
}
