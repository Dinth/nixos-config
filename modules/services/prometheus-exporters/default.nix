{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.prometheus-exporters;

  # Source-restricted firewall rule. Ports allowed only from the
  # explicit scrapeAllowFrom IPs; the rest of the LAN gets dropped
  # by the default firewall policy.
  scrapeRule = let
    ports = ["9100" "9558"] ++ lib.optional cfg.smartctl.enable "9633";
    portList = lib.concatStringsSep ", " ports;
  in
    lib.concatMapStrings (ip: ''
      ip saddr ${ip} tcp dport { ${portList} } accept
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
        ];
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

    networking.firewall.extraInputRules = scrapeRule;
  };
}
