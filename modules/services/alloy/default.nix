{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.alloy;

  # Mirrors the journal + relabel block from omv's
  # /opt/docker/loki-promtail/config.alloy so label semantics match
  # (host, unit, level). The `host` label is set from the journal's
  # _HOSTNAME field, so it auto-resolves to the local hostname
  # without us needing to hardcode it.
  configFile = pkgs.writeText "alloy-config.alloy" ''
    // Where to ship the logs
    loki.write "omv_loki" {
      endpoint {
        url = "${cfg.lokiUrl}"
      }
    }

    // Read journald
    loki.source.journal "systemd" {
      path       = "/var/log/journal"
      max_age = "12h"
      labels     = { job = "systemd" }
      forward_to = [loki.relabel.systemd.receiver]
    }

    // Rewrite raw journal fields into the labels Grafana expects.
    loki.relabel "systemd" {
      forward_to = [loki.write.omv_loki.receiver]

      // Journal fields whose name itself begins with `_` (e.g. _SYSTEMD_UNIT,
      // _HOSTNAME) end up double-underscored in Alloy's label namespace:
      // prefix `__journal_` + lowercased field `_systemd_unit` =
      // `__journal__systemd_unit`. Fields without a leading underscore
      // (PRIORITY_KEYWORD) stay single-underscored.
      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["unit"]
        regex         = "(.*)\\.service"
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "host"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }
  '';
in {
  options.alloy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Ship journald logs to a remote Loki via Grafana Alloy.";
    };

    lokiUrl = mkOption {
      type = types.str;
      default = "http://10.10.1.13:3100/loki/api/v1/push";
      description = "Loki push URL. Default targets the omv loki stack.";
    };
  };

  config = mkIf cfg.enable {
    services.alloy = {
      enable = true;
      configPath = configFile;
    };
    # journald access — the NixOS alloy module sets
    # serviceConfig.SupplementaryGroups = ["systemd-journal"]
    # automatically. DynamicUser=true so we can't pin extraGroups
    # via users.users.alloy here.
  };
}
