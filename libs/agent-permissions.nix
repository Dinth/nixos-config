{lib, ...}: let
  inherit (lib) mkOption types;
in {
  # Shared permission lists for AI coding agents. Both modules/apps/
  # claude-code and modules/apps/opencode read from here so they stay
  # in lockstep — adding a tool to one automatically permits it in
  # the other.
  #
  # Each Bash entry is a literal command prefix (no glob, no rtk
  # prefix). The consuming modules wrap it for their own syntax:
  #   - claude-code: `Bash(<cmd>:*)` and `Bash(rtk <cmd>:*)`
  #   - opencode:    `"<cmd>*" = "allow|ask"` and `"rtk <cmd>*"`
  # The rtk mirror exists because RTK's PreToolUse hook rewrites
  # every bash invocation to `rtk <cmd>`, which then needs its own
  # permission entry.
  options.agentPermissions = {
    readOnlyBash = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Bash command prefixes that run without prompting.";
      default = [
        # Git read-only
        "git status"
        "git log"
        "git diff"
        "git show"
        "git branch"
        "git remote"
        "git config --get"
        "git config --list"
        "git rev-parse"
        "git ls-files"
        "git ls-remote"
        "git describe"
        "git tag --list"
        "git blame"
        "git shortlog"
        "git reflog"
        # Nix read-only
        "nix search"
        "nix eval"
        "nix show-config"
        "nix flake show"
        "nix flake check"
        "nix flake info"
        "nix flake metadata"
        "nix log"
        "nix run nixpkgs#alejandra"
        "nix-instantiate --parse"
        "nix-instantiate --show-trace"
        # `nix fmt` writes formatted .nix files in place — technically a
        # mutation, but idempotent and trivially revertable via git, so
        # safe to allow without prompting.
        "nix fmt"
        # Scoped to the flake check derivations (alejandra/deadnix/statix
        # + host toplevels) — not a blanket `nix build` so the agents
        # can't pull arbitrary derivations from nixpkgs.
        "nix build .#checks"
        # Standalone lint binaries (also reachable via `nix flake check`).
        "alejandra"
        "deadnix"
        "statix"
        # Nix install / store diagnostics
        "nix-info"
        "nix-store -q"
        "nix-tree"
        "nix-diff"
        "nh search"
        # File listing / inspection
        "ls"
        "pwd"
        "find"
        "grep"
        "rg"
        "cat"
        "head"
        "tail"
        "less"
        "wc"
        "sort"
        "uniq"
        "file"
        "stat"
        "tree"
        "eza"
        "diff"
        "mkdir"
        "chmod"
        "readlink"
        "realpath"
        "strings"
        "xxd"
        "hexdump"
        # Text shape-shifting — pure stdin → stdout, no writes
        "cut"
        "tr"
        "paste"
        "tac"
        "column"
        # Structured-data query
        "jq"
        "yq"
        # systemd / journal read-only
        "journalctl"
        "systemctl status"
        "systemctl is-active"
        "systemctl is-enabled"
        "systemctl list-units"
        "systemctl list-unit-files"
        "systemctl list-timers"
        "systemctl show"
        "dmesg"
        # System info
        "uname"
        "hostname"
        "whoami"
        "id"
        "which"
        "type"
        "date"
        "uptime"
        "uuidgen"
        "df"
        "du"
        "free"
        "lsblk"
        "lsusb"
        "lspci"
        "sensors"
        # Network read-only
        "ip addr"
        "ip route"
        "ip link"
        "ss"
        "ps"
        "pgrep"
        "dig"
        "doggo"
        # Audio / printing / desktop
        "pactl list"
        "pw-top"
        "lpstat"
        "lpinfo"
        "qdbus"
        # Media inspection (read-only metadata extraction)
        "ffprobe"
        # Docker read-only
        "docker ps"
        "docker logs"
        "docker inspect"
        "docker images"
        "docker stats"
        "docker version"
        "docker info"
        "docker network ls"
        "docker network inspect"
        "docker volume ls"
        "docker volume inspect"
        # GitHub read-only
        "gh pr list"
        "gh pr view"
        "gh issue list"
        "gh issue view"
        "gh repo view"
        "gh repo list"
        "gh run list"
        "gh run view"
        "gh workflow list"
        "gh workflow view"
        "gh release list"
        "gh release view"
        "gh api"
      ];
    };

    askBash = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = ''
        Bash command prefixes that require explicit approval. Includes
        `env` — `env` with no args dumps the entire process environment,
        which can contain MCP auth tokens (HOMEASSISTANT_MCP_URL etc.)
        and the transcript would record them.
      '';
      default = [
        # Git write
        "git config"
        "git add"
        "git reset"
        "git commit"
        "git push"
        "git pull"
        "git merge"
        "git rebase"
        "git checkout"
        "git switch"
        "git stash"
        # Filesystem write
        "rm"
        "mv"
        "cp"
        # Process management
        "kill"
        "killall"
        "pkill"
        # Privilege escalation
        "sudo"
        "nixos-rebuild"
        # Network egress
        "ping"
        "curl"
        "wget"
        "ssh"
        "scp"
        "rsync"
        # systemd write
        "systemctl start"
        "systemctl stop"
        "systemctl restart"
        "systemctl reload"
        "systemctl enable"
        "systemctl disable"
        # Docker write
        "docker compose"
        "docker run"
        "docker stop"
        # GitHub write
        "gh pr create"
        "gh issue create"
        # Network probing / device control — read forms are safe but
        # write forms (`nmcli con up`, `xrandr --output …`, `mount …`)
        # mutate, and disambiguating is brittle, so prompt for all.
        "nmap"
        "nmcli"
        "xrandr"
        "mount"
        # See description above.
        "env"
      ];
    };

    mcpReadOnly = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = ''
        MCP tool names that bypass the prompt for read-only queries.
        Claude Code uses these via permissions.allow; opencode's
        permission model doesn't have per-tool MCP granularity so
        these are not consumed there.
      '';
      default = [
        "mcp__nixos__home_manager_options_by_prefix"
        # Grafana MCP — read-only queries only.
        "mcp__grafana__query_prometheus"
        "mcp__grafana__query_prometheus_histogram"
        "mcp__grafana__list_prometheus_label_names"
        "mcp__grafana__list_prometheus_label_values"
        "mcp__grafana__list_prometheus_metric_names"
        "mcp__grafana__list_prometheus_metric_metadata"
        "mcp__grafana__query_loki_logs"
        "mcp__grafana__query_loki_stats"
        "mcp__grafana__query_loki_patterns"
        "mcp__grafana__list_loki_label_names"
        "mcp__grafana__list_loki_label_values"
        "mcp__grafana__search_dashboards"
        "mcp__grafana__search_folders"
        "mcp__grafana__get_dashboard_by_uid"
        "mcp__grafana__get_dashboard_summary"
        "mcp__grafana__get_dashboard_property"
        "mcp__grafana__get_dashboard_panel_queries"
        "mcp__grafana__get_annotations"
        "mcp__grafana__get_annotation_tags"
        "mcp__grafana__generate_deeplink"
        # Home Assistant MCP — read-only queries only.
        "mcp__homeassistant__ha_get_overview"
        "mcp__homeassistant__ha_get_state"
        "mcp__homeassistant__ha_get_entity"
        "mcp__homeassistant__ha_get_entity_exposure"
        "mcp__homeassistant__ha_get_device"
        "mcp__homeassistant__ha_get_integration"
        "mcp__homeassistant__ha_get_zone"
        "mcp__homeassistant__ha_get_todo"
        "mcp__homeassistant__ha_get_addon"
        "mcp__homeassistant__ha_get_blueprint"
        "mcp__homeassistant__ha_get_camera_image"
        "mcp__homeassistant__ha_get_history"
        "mcp__homeassistant__ha_get_logs"
        "mcp__homeassistant__ha_get_system_health"
        "mcp__homeassistant__ha_get_updates"
        "mcp__homeassistant__ha_get_automation_traces"
        "mcp__homeassistant__ha_get_helper_schema"
        "mcp__homeassistant__ha_get_operation_status"
        "mcp__homeassistant__ha_get_skill_home_assistant_best_practices"
        "mcp__homeassistant__ha_search_entities"
        "mcp__homeassistant__ha_deep_search"
        "mcp__homeassistant__ha_list_floors_areas"
        "mcp__homeassistant__ha_list_resources"
        "mcp__homeassistant__ha_list_services"
        "mcp__homeassistant__ha_read_resource"
        "mcp__homeassistant__ha_check_config"
        "mcp__homeassistant__ha_eval_template"
        "mcp__homeassistant__ha_config_get_automation"
        "mcp__homeassistant__ha_config_get_calendar_events"
        "mcp__homeassistant__ha_config_get_category"
        "mcp__homeassistant__ha_config_get_dashboard"
        "mcp__homeassistant__ha_config_get_label"
        "mcp__homeassistant__ha_config_get_scene"
        "mcp__homeassistant__ha_config_get_script"
        "mcp__homeassistant__ha_config_list_areas"
        "mcp__homeassistant__ha_config_list_dashboard_resources"
        "mcp__homeassistant__ha_config_list_floors"
        "mcp__homeassistant__ha_config_list_groups"
        "mcp__homeassistant__ha_config_list_helpers"
        "mcp__homeassistant__ha_hacs_search"
        "mcp__homeassistant__ha_hacs_repository_info"
      ];
    };
  };
}
