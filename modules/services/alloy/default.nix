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

    // Drop known-noise floods before they reach Loki:
    //  1. pipewire-pulse "Bad file descriptor" storms from clients that
    //     connect-and-drop the pulse socket every poll (lnxlink) — peaked
    //     at ~113k lines/day before the lnxlink interval fix.
    //  2. kernel "audit: error in audit_log_subj_ctx" — audit+AppArmor
    //     noise on kernels >= 7.0, logged at err priority (~1k/day).
    loki.process "drop_noise" {
      forward_to = [loki.write.omv_loki.receiver]

      stage.drop {
        expression = ".*mod.protocol-pulse.*Bad file descriptor.*"
      }
      stage.drop {
        expression = ".*audit: error in audit_log_subj_ctx.*"
      }
    }

    // Promote only a tight, low-cardinality set of journal fields to Loki
    // index labels. A blanket labelmap of every __journal_* field (pid,
    // cmdline, code_line, invocation_id, cgroup, ...) explodes stream
    // cardinality and wrecks Loki query performance, so we map fields
    // explicitly instead. Everything else stays in the log line / dropped.
    loki.relabel "systemd" {
      forward_to = [loki.process.drop_noise.receiver]

      // _SYSTEMD_UNIT (fields starting with _ get a doubled underscore)
      // with the .service suffix stripped → `unit`.
      rule {
        source_labels = ["__journal__systemd_unit"]
        regex         = "(.*)\\.service"
        target_label  = "unit"
      }
      // Synthesized priority keyword (emerg..debug) → `level`.
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
      // Program name — low cardinality, handy for filtering.
      rule {
        source_labels = ["__journal_syslog_identifier"]
        target_label  = "syslog_identifier"
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
