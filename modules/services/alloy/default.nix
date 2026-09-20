{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.alloy;

  # Docker log collection rides on the existing `docker` toggle rather than a
  # per-host switch of its own: every host that runs a Docker daemon wants its
  # container logs in Loki, and no host without one can produce them.
  dockerLogs = config.docker.enable;
  unixSocket = lib.hasPrefix "unix://" cfg.dockerHost;

  # `host` is injected as a static label here rather than derived from the
  # journal's _HOSTNAME field — we know the hostname at Nix eval time, and
  # the various `__journal_*` / `__journal__*` source_label spellings have
  # been unreliable across Alloy releases.
  configFile = pkgs.writeText "alloy-config.alloy" (
    ''
      // Where to ship the logs. external_labels applies `host` to every stream
      // this instance writes — journal and Docker alike — so neither source
      // needs a host rule of its own.
      loki.write "omv_loki" {
        endpoint {
          url = "${cfg.lokiUrl}"
        }
        external_labels = {
          host = "${config.networking.hostName}",
        }
      }

      // Promote only a tight, low-cardinality set of journal fields to Loki
      // index labels. A blanket labelmap of every __journal_* field (pid,
      // cmdline, code_line, invocation_id, cgroup, ...) explodes stream
      // cardinality and wrecks Loki query performance, so we map fields
      // explicitly instead.
      //
      // forward_to is deliberately empty: this component exists only to export
      // `.rules`. The __journal_* metadata labels are consumed and stripped by
      // loki.source.journal itself, so they are NOT visible to a loki.relabel
      // placed downstream of the source — rules must be handed to the source
      // via its relabel_rules argument instead. Wiring this as a downstream
      // stage is why `unit` and `level` never appeared on these hosts.
      loki.relabel "journal_fields" {
        forward_to = []

        // _SYSTEMD_UNIT (fields starting with _ get a doubled underscore)
        // copied verbatim, then .service stripped by the rule below. Two rules,
        // not one: a single "(.*)\\.service" rule drops the label entirely for
        // units that don't match (.scope, user@0.service's siblings), whereas
        // r720 keeps those intact.
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["unit"]
          regex         = "(.+)\\.service"
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

      // Read journald. `job` is pinned to the value Alloy would generate from
      // this component's own ID, which is what the Alloy container on r720-omv
      // emits — spelling it out keeps the two hosts on one selector without
      // depending on that default staying stable across Alloy releases.
      loki.source.journal "systemd" {
        path          = "/var/log/journal"
        max_age       = "12h"
        labels        = {
          job = "loki.source.journal.systemd",
        }
        relabel_rules = loki.relabel.journal_fields.rules
        forward_to    = [loki.process.drop_noise.receiver]
      }

      // Drop known-noise floods before they reach Loki:
      //  1. pipewire-pulse "Bad file descriptor" storms from clients that
      //     connect-and-drop the pulse socket every poll (lnxlink) — peaked
      //     at ~113k lines/day before the lnxlink interval fix.
      //  2. kernel "audit: error in audit_log_subj_ctx" — audit+AppArmor
      //     noise on kernels >= 7.0, logged at err priority (~1k/day).
      // Journal-only: container logs go straight to the write path.
      loki.process "drop_noise" {
        forward_to = [loki.write.omv_loki.receiver]

        stage.drop {
          expression = ".*mod.protocol-pulse.*Bad file descriptor.*"
        }
        stage.drop {
          expression = ".*audit: error in audit_log_subj_ctx.*"
        }
      }
    ''
    + lib.optionalString dockerLogs ''

      // ---------------------------------------------------------------------
      // Docker container logs. Emits the same four labels as the Alloy
      // container on r720-omv — host (from external_labels), job, container,
      // service — so a {job="docker"} selector spans both hosts. `service_name`
      // is not set: Loki 3.x derives it and lands on the container name.
      // `level` is not set either; Loki attaches detected_level as structured
      // metadata.
      // ---------------------------------------------------------------------
      discovery.docker "containers" {
        host             = "${cfg.dockerHost}"
        refresh_interval = "15s"
      }

      // No labelkeep/labeldrop here: loki.source.docker addresses each container
      // by __meta_docker_container_id, so stripping __meta_* breaks collection.
      discovery.relabel "containers" {
        targets = discovery.docker.containers.targets

        // The leading "/" Docker puts on container names has to go, or every
        // label reads "/adguardhome" and stops matching the r720 dashboards.
        rule {
          source_labels = ["__meta_docker_container_name"]
          regex         = "/?(.*)"
          target_label  = "container"
        }
        rule {
          source_labels = ["__meta_docker_container_name"]
          regex         = "/?(.*)"
          target_label  = "service"
        }
        rule {
          target_label = "job"
          replacement  = "docker"
        }
      }

      // Same daemon as discovery.docker above — the two must agree.
      // Read offsets are persisted under the unit's StateDirectory (alloy),
      // so a restart resumes rather than replaying every container's log.
      loki.source.docker "containers" {
        host             = "${cfg.dockerHost}"
        targets          = discovery.relabel.containers.output
        forward_to       = [loki.write.omv_loki.receiver]
        refresh_interval = "15s"
      }
    ''
  );
in {
  options.alloy = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Ship journald logs to a remote Loki via Grafana Alloy. On hosts where
        `docker.enable` is also set, Docker container logs are shipped too.
      '';
    };

    lokiUrl = mkOption {
      type = types.str;
      default = "http://10.10.1.13:3100/loki/api/v1/push";
      description = "Loki push URL. Default targets the omv loki stack.";
    };

    dockerHost = mkOption {
      type = types.str;
      default = "unix:///var/run/docker.sock";
      example = "tcp://10.10.1.12:2377";
      description = ''
        Docker daemon address used for container log collection. Only consulted
        when `docker.enable` is true.

        SECURITY: the default reads the raw socket, which requires the `docker`
        group and is therefore root-equivalent access to the host. Pointing this
        at a filtered read-only socket proxy (as the Alloy container on omv does)
        is the better posture; the `docker` group is then not granted. A proxy
        must permit GET on containers/.* — both the container list and the log
        endpoint live there.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.alloy = {
      enable = true;
      configPath = configFile;
      # Alloy otherwise retries stats.grafana.org forever and logs ~6 lines per
      # failure every 30s — noise that this very config then ships to Loki.
      extraFlags = ["--disable-reporting"];
    };

    # journald access — the NixOS alloy module sets
    # serviceConfig.SupplementaryGroups = ["systemd-journal"] automatically.
    # DynamicUser=true so we can't pin extraGroups via users.users.alloy;
    # systemd unit list options merge by concatenation, so this appends to
    # that list rather than replacing it.
    systemd.services.alloy.serviceConfig.SupplementaryGroups =
      lib.optionals (dockerLogs && unixSocket) ["docker"];
  };
}
