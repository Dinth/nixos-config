{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.prometheus-exporters;

  # Source-restricted firewall rules. Ports allowed only from the
  # explicit scrapeAllowFrom IPs; the rest of the LAN is dropped by
  # the default firewall policy.
  #
  # `extraCommands` (iptables) is the active backend on dinth + r230
  # today (networking.nftables.enable = false). `extraInputRules`
  # is the nftables equivalent and is silently no-op on iptables
  # hosts — kept for the eventual migration so we don't have to
  # touch this module again.
  ports = ["9100" "9558"] ++ lib.optional cfg.smartctl.enable "9633";
  ipPortList = lib.concatStringsSep "," ports;
  nftPortList = lib.concatStringsSep ", " ports;

  iptablesStart =
    lib.concatMapStrings (ip: ''
      iptables -A nixos-fw -s ${ip} -p tcp -m multiport --dports ${ipPortList} -j nixos-fw-accept
    '')
    cfg.scrapeAllowFrom;
  iptablesStop =
    lib.concatMapStrings (ip: ''
      iptables -D nixos-fw -s ${ip} -p tcp -m multiport --dports ${ipPortList} -j nixos-fw-accept || true
    '')
    cfg.scrapeAllowFrom;
  nftablesRule =
    lib.concatMapStrings (ip: ''
      ip saddr ${ip} tcp dport { ${nftPortList} } accept
    '')
    cfg.scrapeAllowFrom;
in {
  options.prometheus-exporters = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose Prometheus exporters for remote scraping.";
    };

    scrapeAllowFrom = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["10.10.1.13"];
      description = "IP addresses allowed to reach the exporter ports.";
    };

    smartctl.enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable smartctl_exporter. Off by default — on VMs the
        underlying "disks" are virtio and SMART data is empty/fake.
        Enable on physical hosts with NVMe/SATA drives.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.exporters = {
      # Host-level metrics: CPU, memory, disk, network, etc.
      # hwmon / thermal_zone / cpufreq are default collectors and
      # produce empty data on VMs — harmless, no need to gate.
      node = {
        enable = true;
        port = 9100;
        enabledCollectors = [
          "processes"
          "logind"
          "tcpstat"
          # textfile: lets other units (backups, nixos-rebuild, etc.) drop
          # *.prom files that get scraped as first-class metrics for free.
          "textfile"
        ];
        extraFlags = ["--collector.textfile.directory=/var/lib/node_exporter/textfile"];
      };

      # Per-unit state (active/failed), restart counts, task counts.
      # Catches "docker.service died at 3am" without custom monitoring.
      systemd = {
        enable = true;
        port = 9558;
      };

      # Drive SMART attributes — reallocated sectors, temperature,
      # SSD wear. Off unless explicitly enabled.
      smartctl = {
        inherit (cfg.smartctl) enable;
        port = 9633;
      };
    };

    # World-readable drop dir for the textfile collector. Other units write
    # <name>.prom here; node_exporter (DynamicUser) only needs to read it.
    systemd.tmpfiles.rules = ["d /var/lib/node_exporter/textfile 0755 root root -"];

    # "Reboot needed" metric. With the rolling `nh os switch -u` workflow the
    # booted kernel can silently lag the current generation's for weeks (27
    # days observed). Compare the two and publish via the textfile collector;
    # Grafana alerts on nixos_reboot_required == 1.
    systemd.services.reboot-required-metric = {
      script = ''
        set -euo pipefail
        booted=$(readlink /run/booted-system/kernel)
        current=$(readlink /run/current-system/kernel)
        dir=/var/lib/node_exporter/textfile
        tmp=$(mktemp "$dir/.reboot_required.XXXXXX")
        {
          echo "# HELP nixos_reboot_required 1 when the booted kernel differs from the current generation's kernel."
          echo "# TYPE nixos_reboot_required gauge"
          if [ "$booted" = "$current" ]; then
            echo "nixos_reboot_required 0"
          else
            echo "nixos_reboot_required 1"
          fi
        } > "$tmp"
        chmod 0644 "$tmp"
        mv "$tmp" "$dir/reboot_required.prom"
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        # Full sandbox — the script only reads two /run symlinks and writes
        # one file into the textfile drop dir.
        ProtectSystem = "strict";
        ReadWritePaths = ["/var/lib/node_exporter/textfile"];
        ProtectHome = true;
        PrivateTmp = true;
        PrivateNetwork = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = [""];
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
      };
    };
    systemd.timers.reboot-required-metric = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "15min";
      };
    };

    networking.firewall = {
      extraCommands = iptablesStart;
      extraStopCommands = iptablesStop;
      extraInputRules = nftablesRule;
    };
  };
}
