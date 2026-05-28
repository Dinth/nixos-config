{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.alloy;

  # `host` is injected as a static label here rather than derived from the
  # journal's _HOSTNAME field — we know the hostname at Nix eval time, and
  # the various `__journal_*` / `__journal__*` source_label spellings have
  # been unreliable across Alloy releases. `unit` and `level` are still
  # mapped from journal fields via labelmap so we don't have to know the
  # exact prefix Alloy picks.
  configFile = pkgs.writeText "alloy-config.alloy" ''
    // Where to ship the logs
    loki.write "omv_loki" {
      endpoint {
        url = "${cfg.lokiUrl}"
      }
    }

    // Read journald. host is set statically; job is the source tag.
    loki.source.journal "systemd" {
      path       = "/var/log/journal"
      max_age = "12h"
      labels     = {
        job  = "systemd",
        host = "${config.networking.hostName}",
      }
      forward_to = [loki.relabel.systemd.receiver]
    }

    // Map any __journal*-prefixed labels to their plain names so unit
    // and level fall out without us needing the exact prefix.
    loki.relabel "systemd" {
      forward_to = [loki.write.omv_loki.receiver]

      rule {
        action = "labelmap"
        regex  = "__journal_+(.+)"
      }
      rule {
        source_labels = ["systemd_unit"]
        regex         = "(.*)\\.service"
        target_label  = "unit"
      }
      rule {
        source_labels = ["priority_keyword"]
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
