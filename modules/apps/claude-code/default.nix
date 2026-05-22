{
  config,
  lib,
  pkgs,
  home-manager,
  ...
}: let
  inherit (lib) mkIf mkOption;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;
  userHome = "/home/${primaryUsername}";

  # User-scope MCP servers — merged into ~/.claude.json at activation time
  # (instead of settings.json, which is not the documented MCP location).
  # Project-scope servers live in .mcp.json at each project root.
  globalMcpServers = {
    grafana = {
      type = "http";
      url = "http://10.10.1.13:5133/mcp";
    };
    unifi = {
      type = "http";
      url = "http://10.10.1.13:5134/mcp";
    };
  };

  # Settings attrset — serialised to JSON and installed as a real mutable
  # file via home.activation (see below). programs.claude-code.settings
  # produces a read-only Nix store symlink which breaks Claude Code's
  # permission enforcement (upstream issue #3575).
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";

    model = "opus";

    # Drop the deprecated includeCoAuthoredBy in favour of explicit attribution.
    # Project CLAUDE.md says no Co-Authored-By lines, so suppress both.
    attribution = {
      commit = "";
      pr = "";
    };

    # Flicker-free rendering + visible extended thinking.
    tui = "fullscreen";
    showThinkingSummaries = true;

    # Pinned channel — the binary is Nix-managed anyway, so the latest channel
    # buys nothing but extra regressions.
    autoUpdatesChannel = "stable";

    editorMode = "vim";

    # Suppress the periodic "rate this session" survey.
    feedbackSurveyRate = 0;

    statusLine = {
      type = "command";
      command = lib.getExe statusLineScript;
      padding = 1;
      # The statusline script renders vim.mode itself; suppress the duplicate
      # `-- INSERT --` indicator below the prompt.
      hideVimModeIndicator = true;
    };

    # Global per-session environment for Claude Code itself.
    env = {
      # Defer MCP tool schemas to keep context lean.
      ENABLE_TOOL_SEARCH = "true";
      # Raise per-tool output ceiling for large MCP responses.
      MAX_MCP_OUTPUT_TOKENS = "50000";
      # Give slow MCP servers more time to start.
      MCP_TIMEOUT = "10000";
      # Record RTK hook rewrite outcomes locally so `rtk hook-audit` and
      # `rtk gain` / `rtk cc-economics` can show what was saved. Local
      # audit data only, no telemetry.
      RTK_HOOK_AUDIT = "1";
      # Disable TUI mouse capture so Konsole's right-click context menu
      # (and native selection) keeps working. Keyboard scroll still works.
      CLAUDE_CODE_DISABLE_MOUSE = "1";
    };

    hooks = {
      # RTK ships a first-class Claude Code PreToolUse handler that reads
      # the documented hook payload from stdin and emits the canonical
      # hookSpecificOutput response shape. Calling `rtk hook claude`
      # directly is the supported integration — no wrapper script needed.
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${lib.getExe pkgs.rtk} hook claude";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = toString stopNotifyScript;
            }
          ];
        }
      ];
    };

    permissions = {
      # Documented mechanism for granting access to directories outside the
      # project root — replaces the ad-hoc Read(...) entries that used to
      # live in `allow`.
      additionalDirectories = [
        "${userHome}/.claude"
        "${userHome}/.config/opencode"
      ];

      allow = [
        # Git read-only
        "Bash(git status:*)"
        "Bash(git log:*)"
        "Bash(git diff:*)"
        "Bash(git show:*)"
        "Bash(git branch:*)"
        "Bash(git remote:*)"
        "Bash(git config --get:*)"
        "Bash(git config --list:*)"
        "Bash(git rev-parse:*)"
        "Bash(git ls-files:*)"
        "Bash(git ls-remote:*)"
        "Bash(git describe:*)"
        "Bash(git tag --list:*)"
        "Bash(git blame:*)"
        "Bash(git shortlog:*)"
        "Bash(git reflog:*)"
        # Nix read-only
        "Bash(nix search:*)"
        "Bash(nix eval:*)"
        "Bash(nix show-config:*)"
        "Bash(nix flake show:*)"
        "Bash(nix flake check:*)"
        "Bash(nix flake info:*)"
        "Bash(nix flake metadata:*)"
        "Bash(nix log:*)"
        "Bash(nix run nixpkgs#alejandra:*)"
        "Bash(nix-instantiate --parse:*)"
        "Bash(nix-instantiate --show-trace:*)"
        "Bash(nh search:*)"
        # File listing / inspection
        "Bash(ls:*)"
        "Bash(pwd:*)"
        "Bash(find:*)"
        "Bash(grep:*)"
        "Bash(rg:*)"
        "Bash(cat:*)"
        "Bash(head:*)"
        "Bash(tail:*)"
        "Bash(less:*)"
        "Bash(wc:*)"
        "Bash(sort:*)"
        "Bash(uniq:*)"
        "Bash(file:*)"
        "Bash(stat:*)"
        "Bash(tree:*)"
        "Bash(eza:*)"
        "Bash(mkdir:*)"
        "Bash(chmod:*)"
        # systemd / journal read-only
        "Bash(journalctl:*)"
        "Bash(systemctl status:*)"
        "Bash(systemctl is-active:*)"
        "Bash(systemctl is-enabled:*)"
        "Bash(systemctl list-units:*)"
        "Bash(systemctl list-unit-files:*)"
        "Bash(systemctl list-timers:*)"
        "Bash(systemctl show:*)"
        "Bash(dmesg:*)"
        # System info
        "Bash(uname:*)"
        "Bash(hostname:*)"
        "Bash(whoami:*)"
        "Bash(id:*)"
        "Bash(which:*)"
        "Bash(type:*)"
        "Bash(date:*)"
        "Bash(uptime:*)"
        "Bash(uuidgen:*)"
        "Bash(df:*)"
        "Bash(du:*)"
        "Bash(free:*)"
        "Bash(lsblk:*)"
        "Bash(lsusb:*)"
        "Bash(lspci:*)"
        # `Bash(env:*)` moved to `ask` — bare `env` dumps the entire process
        # environment which can include MCP auth tokens (HOMEASSISTANT_MCP_URL,
        # any future ragenix-injected vars). The transcript would record them.
        # Network read-only
        "Bash(ip addr:*)"
        "Bash(ip route:*)"
        "Bash(ip link:*)"
        "Bash(ss:*)"
        "Bash(ps:*)"
        "Bash(pgrep:*)"
        # Audio / printing / desktop
        "Bash(pactl list:*)"
        "Bash(pw-top:*)"
        "Bash(lpstat:*)"
        "Bash(lpinfo:*)"
        "Bash(qdbus:*)"
        # Docker read-only
        "Bash(docker ps:*)"
        "Bash(docker logs:*)"
        "Bash(docker inspect:*)"
        "Bash(docker images:*)"
        "Bash(docker stats:*)"
        "Bash(docker version:*)"
        "Bash(docker info:*)"
        "Bash(docker network ls:*)"
        "Bash(docker network inspect:*)"
        "Bash(docker volume ls:*)"
        "Bash(docker volume inspect:*)"
        # GitHub read-only
        "Bash(gh pr list:*)"
        "Bash(gh pr view:*)"
        "Bash(gh issue list:*)"
        "Bash(gh issue view:*)"
        "Bash(gh repo view:*)"
        "Bash(gh api:*)"
        # RTK-prefixed variants — the `rtk hook claude` PreToolUse handler
        # rewrites every Bash invocation (e.g. `ls -la` → `rtk ls -la`) to
        # squeeze tokens out of large outputs. Without these mirrors the
        # rewritten command no longer matches the original allow entry and
        # Claude falls back to prompting on every call. Deny rules for
        # secrets/**/.env still get bypassed by the rewrite — accepted
        # trade-off, see PreToolUse hook above.
        # Git read-only
        "Bash(rtk git status:*)"
        "Bash(rtk git log:*)"
        "Bash(rtk git diff:*)"
        "Bash(rtk git show:*)"
        "Bash(rtk git branch:*)"
        "Bash(rtk git remote:*)"
        "Bash(rtk git config --get:*)"
        "Bash(rtk git config --list:*)"
        "Bash(rtk git rev-parse:*)"
        "Bash(rtk git ls-files:*)"
        "Bash(rtk git ls-remote:*)"
        "Bash(rtk git describe:*)"
        "Bash(rtk git tag --list:*)"
        "Bash(rtk git blame:*)"
        "Bash(rtk git shortlog:*)"
        "Bash(rtk git reflog:*)"
        # Nix read-only
        "Bash(rtk nix search:*)"
        "Bash(rtk nix eval:*)"
        "Bash(rtk nix show-config:*)"
        "Bash(rtk nix flake show:*)"
        "Bash(rtk nix flake check:*)"
        "Bash(rtk nix flake info:*)"
        "Bash(rtk nix flake metadata:*)"
        "Bash(rtk nix log:*)"
        "Bash(rtk nix run nixpkgs#alejandra:*)"
        "Bash(rtk nix-instantiate --parse:*)"
        "Bash(rtk nix-instantiate --show-trace:*)"
        "Bash(rtk nh search:*)"
        # File listing / inspection
        "Bash(rtk ls:*)"
        "Bash(rtk pwd:*)"
        "Bash(rtk find:*)"
        "Bash(rtk grep:*)"
        "Bash(rtk rg:*)"
        "Bash(rtk read:*)"
        "Bash(rtk cat:*)"
        "Bash(rtk head:*)"
        "Bash(rtk tail:*)"
        "Bash(rtk less:*)"
        "Bash(rtk wc:*)"
        "Bash(rtk sort:*)"
        "Bash(rtk uniq:*)"
        "Bash(rtk file:*)"
        "Bash(rtk stat:*)"
        "Bash(rtk tree:*)"
        "Bash(rtk eza:*)"
        "Bash(rtk mkdir:*)"
        "Bash(rtk chmod:*)"
        # systemd / journal read-only
        "Bash(rtk journalctl:*)"
        "Bash(rtk systemctl status:*)"
        "Bash(rtk systemctl is-active:*)"
        "Bash(rtk systemctl is-enabled:*)"
        "Bash(rtk systemctl list-units:*)"
        "Bash(rtk systemctl list-unit-files:*)"
        "Bash(rtk systemctl list-timers:*)"
        "Bash(rtk systemctl show:*)"
        "Bash(rtk dmesg:*)"
        # System info
        "Bash(rtk uname:*)"
        "Bash(rtk hostname:*)"
        "Bash(rtk whoami:*)"
        "Bash(rtk id:*)"
        "Bash(rtk which:*)"
        "Bash(rtk type:*)"
        "Bash(rtk date:*)"
        "Bash(rtk uptime:*)"
        "Bash(rtk uuidgen:*)"
        "Bash(rtk df:*)"
        "Bash(rtk du:*)"
        "Bash(rtk free:*)"
        "Bash(rtk lsblk:*)"
        "Bash(rtk lsusb:*)"
        "Bash(rtk lspci:*)"
        # Network read-only
        "Bash(rtk ip addr:*)"
        "Bash(rtk ip route:*)"
        "Bash(rtk ip link:*)"
        "Bash(rtk ss:*)"
        "Bash(rtk ps:*)"
        "Bash(rtk pgrep:*)"
        # Audio / printing / desktop
        "Bash(rtk pactl list:*)"
        "Bash(rtk pw-top:*)"
        "Bash(rtk lpstat:*)"
        "Bash(rtk lpinfo:*)"
        "Bash(rtk qdbus:*)"
        # Docker read-only
        "Bash(rtk docker ps:*)"
        "Bash(rtk docker logs:*)"
        "Bash(rtk docker inspect:*)"
        "Bash(rtk docker images:*)"
        "Bash(rtk docker stats:*)"
        "Bash(rtk docker version:*)"
        "Bash(rtk docker info:*)"
        "Bash(rtk docker network ls:*)"
        "Bash(rtk docker network inspect:*)"
        "Bash(rtk docker volume ls:*)"
        "Bash(rtk docker volume inspect:*)"
        # GitHub read-only
        "Bash(rtk gh pr list:*)"
        "Bash(rtk gh pr view:*)"
        "Bash(rtk gh issue list:*)"
        "Bash(rtk gh issue view:*)"
        "Bash(rtk gh repo view:*)"
        "Bash(rtk gh api:*)"
        # Web + curated MCP tools
        "WebSearch"
        "WebFetch"
        "mcp__nixos__home_manager_options_by_prefix"
        # Grafana MCP — read-only queries only. Write/manage tools
        # (alerting_manage_*, create_annotation, update_annotation,
        # update_dashboard) deliberately omitted so they still prompt.
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
      ];

      ask = [
        # Git write
        "Bash(git config:*)"
        "Bash(git add:*)"
        "Bash(git reset:*)"
        "Bash(git commit:*)"
        "Bash(git push:*)"
        "Bash(git pull:*)"
        "Bash(git merge:*)"
        "Bash(git rebase:*)"
        "Bash(git checkout:*)"
        "Bash(git switch:*)"
        "Bash(git stash:*)"
        # Filesystem write
        "Bash(rm:*)"
        "Bash(mv:*)"
        "Bash(cp:*)"
        # Process management
        "Bash(kill:*)"
        "Bash(killall:*)"
        "Bash(pkill:*)"
        # Privilege escalation
        "Bash(sudo:*)"
        "Bash(nixos-rebuild:*)"
        # Network egress
        "Bash(ping:*)"
        "Bash(curl:*)"
        "Bash(wget:*)"
        "Bash(ssh:*)"
        "Bash(scp:*)"
        "Bash(rsync:*)"
        # systemd write
        "Bash(systemctl start:*)"
        "Bash(systemctl stop:*)"
        "Bash(systemctl restart:*)"
        "Bash(systemctl reload:*)"
        "Bash(systemctl enable:*)"
        "Bash(systemctl disable:*)"
        # Docker write
        "Bash(docker compose:*)"
        "Bash(docker run:*)"
        "Bash(docker stop:*)"
        # GitHub write
        "Bash(gh pr create:*)"
        "Bash(gh issue create:*)"
        # See note above re: env-var disclosure in transcripts.
        "Bash(env:*)"
      ];

      # Project-relative deny patterns need the `./` prefix to match. Nested
      # globs catch .env files in subdirectories (packages/api/.env, etc.).
      deny = [
        "Read(./.env)"
        "Read(./.env.*)"
        "Read(./**/.env)"
        "Read(./**/.env.*)"
        "Read(./**/secrets/**)"
        "Read(./**/*.key)"
        "Read(./**/*.pem)"
      ];
    };
  };

  claudeSettingsFile = pkgs.runCommand "claude-code-settings.json" {} ''
    ${lib.getExe pkgs.jq} '.' \
      ${pkgs.writeText "claude-settings-raw.json" (builtins.toJSON claudeSettings)} \
      > $out
  '';

  # Merges the managed user-scope MCP servers into ~/.claude.json without
  # touching mutable state (OAuth tokens, sessions, project-trust map).
  mergeGlobalMcpScript = pkgs.writeShellScript "merge-claude-global-mcp.sh" ''
    set -euo pipefail
    CLAUDE_JSON="$HOME/.claude.json"
    NEW_JSON=${lib.escapeShellArg (builtins.toJSON globalMcpServers)}

    if [ ! -s "$CLAUDE_JSON" ]; then
      ${lib.getExe' pkgs.coreutils "install"} -m 600 /dev/null "$CLAUDE_JSON"
      echo '{}' > "$CLAUDE_JSON"
    fi

    TMP="$(${lib.getExe' pkgs.coreutils "mktemp"} "$CLAUDE_JSON.XXXXXX")"
    ${lib.getExe pkgs.jq} --argjson new "$NEW_JSON" \
      '.mcpServers = ((.mcpServers // {}) + $new)' \
      "$CLAUDE_JSON" > "$TMP"
    ${lib.getExe' pkgs.coreutils "mv"} "$TMP" "$CLAUDE_JSON"
    ${lib.getExe' pkgs.coreutils "chmod"} 600 "$CLAUDE_JSON"
  '';

  # Two-line status bar: model + dir + git branch on line 1,
  # context-usage bar + cost (+ rate limits + RTK savings) on line 2.
  # Catppuccin-ish ANSI palette.
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline.sh";
    runtimeInputs = with pkgs; [jq git coreutils sqlite];
    text = ''
      input=$(cat)

      model=$(jq -r '.model.display_name // .model.id // "?"'         <<<"$input")
      dir=$(jq   -r '.workspace.current_dir // .cwd // "."'            <<<"$input")
      pct_raw=$(jq -r '.context_window.used_percentage // 0'           <<<"$input")
      cost=$(jq -r '.cost.total_cost_usd // 0'                         <<<"$input")
      effort=$(jq -r '.effort.level // empty'                          <<<"$input")
      thinking=$(jq -r 'if .thinking.enabled then "↯" else "" end'     <<<"$input")
      vim_mode=$(jq -r '.vim.mode // empty'                            <<<"$input")
      rl_5h=$(jq -r '.rate_limits.five_hour.used_percentage // empty'  <<<"$input")
      rl_7d=$(jq -r '.rate_limits.seven_day.used_percentage // empty'  <<<"$input")

      pct=''${pct_raw%.*}
      pct=''${pct:-0}

      short_dir=''${dir/#$HOME/\~}

      branch=""
      dirty=""
      if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch=$(git -C "$dir" branch --show-current 2>/dev/null || true)
        if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
          dirty="*"
        fi
      fi

      cost_fmt=$(printf '%.2f' "$cost")

      BW=12
      filled=$((pct * BW / 100))
      [ "$filled" -gt "$BW" ] && filled=$BW
      empty=$((BW - filled))
      bar=""
      for ((i=0;i<filled;i++)); do bar+="▓"; done
      for ((i=0;i<empty;i++));  do bar+="░"; done

      RST=$'\e[0m'
      DIM=$'\e[2m'
      B=$'\e[1m'
      MAUVE=$'\e[38;5;141m'
      BLUE=$'\e[38;5;75m'
      TEAL=$'\e[38;5;73m'
      GREEN=$'\e[38;5;108m'
      YELLOW=$'\e[38;5;179m'

      branch_color=$GREEN
      [ -n "$dirty" ] && branch_color=$YELLOW

      line1="''${MAUVE}''${B}''${model}''${RST}"
      [ -n "$effort" ]   && line1+=" ''${DIM}(''${effort})''${RST}"
      [ -n "$thinking" ] && line1+=" ''${MAUVE}''${thinking}''${RST}"
      line1+="  ''${BLUE}''${short_dir}''${RST}"
      [ -n "$branch" ]   && line1+="  ''${branch_color}⎇ ''${branch}''${dirty}''${RST}"
      [ -n "$vim_mode" ] && line1+="  ''${DIM}[''${vim_mode}]''${RST}"

      line2="''${TEAL}''${bar}''${RST} ''${DIM}''${pct}%''${RST}  ''${YELLOW}\$''${cost_fmt}''${RST}"

      fmt_rl() {
        local pct=$1 label=$2 color
        pct=''${pct%.*}
        pct=''${pct:-0}
        if   [ "$pct" -ge 90 ]; then color=$'\e[38;5;174m'   # rose
        elif [ "$pct" -ge 70 ]; then color=$'\e[38;5;179m'   # peach
        else                         color=$'\e[38;5;108m'   # green
        fi
        printf '  %s%s: %d%%%s' "$color" "$label" "$pct" "$RST"
      }

      [ -n "$rl_5h" ] && line2+=$(fmt_rl "$rl_5h" "5h")
      [ -n "$rl_7d" ] && line2+=$(fmt_rl "$rl_7d" "7d")

      # RTK savings segment: "RTK -49% (587t) / -36% (3.2Kt)"
      # First pair = current Claude session (since cost.total_duration_ms ago).
      # Second pair = all-time across every Claude session.
      # Whole segment hidden when rtk has no history yet (fresh install).
      fmt_tokens() {
        local n=$1
        if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n / 1000000)) $(((n / 100000) % 10))
        elif [ "$n" -ge 1000 ];    then printf '%d.%dK' $((n / 1000))    $(((n / 100)    % 10))
        else                            printf '%d'      "$n"
        fi
      }
      fmt_pair() {
        local pct=$1 saved=$2 sign=""
        [ "$pct" -gt 0 ] && sign="-"
        printf '%s%d%% (%st)' "$sign" "$pct" "$(fmt_tokens "$saved")"
      }
      rtk_db="''${XDG_DATA_HOME:-$HOME/.local/share}/rtk/history.db"
      rtk_segment=""
      if [ -f "$rtk_db" ]; then
        dur_ms=$(jq -r '.cost.total_duration_ms // 0' <<<"$input")
        dur_s=$((dur_ms / 1000))
        # Discard sc (session command count) — present in SELECT so the row
        # shape stays symmetric but unused downstream.
        # rtk stores timestamps as ISO 8601 with `T` separator and nanoseconds
        # (e.g. 2026-05-13T14:52:51.331824182+00:00). sqlite's datetime('now')
        # returns the canonical form `2026-05-13 17:58:16`. Naive string
        # comparison on the raw column treats every row as "after now" because
        # 'T' (0x54) > ' ' (0x20). Wrap the column in datetime() so both sides
        # normalize before comparing. The idx_timestamp index is skipped, but
        # the table is tiny (rtk-rewrite events only) so the cost is trivial.
        rtk_row=$(sqlite3 "$rtk_db" "
          WITH sess AS (
            SELECT COUNT(*) c, COALESCE(SUM(saved_tokens),0) s,
                   COALESCE(CAST(AVG(savings_pct) AS INT),0) p
            FROM commands
            WHERE datetime(timestamp) >= datetime('now', '-' || $dur_s || ' seconds')
          ),
          allt AS (
            SELECT COUNT(*) c, COALESCE(SUM(saved_tokens),0) s,
                   COALESCE(CAST(AVG(savings_pct) AS INT),0) p
            FROM commands
          )
          SELECT s.s, s.p, a.c, a.s, a.p FROM sess s, allt a;
        " 2>/dev/null) || rtk_row=""
        if [ -n "$rtk_row" ]; then
          IFS='|' read -r ss sp ac as ap <<<"$rtk_row" || true
          if [ "''${ac:-0}" -gt 0 ]; then
            sess_str=$(fmt_pair "''${sp:-0}" "''${ss:-0}")
            allt_str=$(fmt_pair "''${ap:-0}" "''${as:-0}")
            rtk_segment="$sess_str / $allt_str"
          fi
        fi
      fi
      [ -n "$rtk_segment" ] && line2+="  ''${MAUVE}RTK ''${rtk_segment}''${RST}"

      printf '%s\n%s' "$line1" "$line2"
    '';
  };

  # Desktop notification when Claude finishes a turn. The hook payload on
  # stdin gives session_id + cwd; we include cwd so notifications across
  # parallel sessions are distinguishable. Failures are swallowed (no DBus
  # in headless / cron contexts).
  stopNotifyScript = pkgs.writeShellScript "claude-stop-notify.sh" ''
    cwd=$(${lib.getExe pkgs.jq} -r '.cwd // empty' 2>/dev/null) || cwd=""
    label=''${cwd##*/}
    ${lib.getExe' pkgs.libnotify "notify-send"} \
      --app-name='Claude Code' \
      --icon=utilities-terminal \
      --urgency=low \
      "Claude finished" \
      "''${label:-session} done" \
      2>/dev/null || true
  '';
in {
  config = mkIf cfg.enable {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        # General logic and compression
        stdenv.cc.cc
        zlib
        zstd
      ];
    };
    environment.systemPackages = with pkgs; [
      nix-output-monitor
      mcp-nixos
    ];
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        yamlfmt
        php83Packages.php-cs-fixer
        shfmt
        shellcheck
        nodePackages.prettier
        djlint
        ruff
        rtk # Rust Token Killer - reduces LLM token consumption
      ];
      # Export HOMEASSISTANT_MCP_URL for Claude Code's project-scope .mcp.json
      # in ~/Documents/nixos-config. The URL contains a private auth key so it
      # lives in ragenix; read at shell startup so it's available whenever
      # `claude` is launched from a zsh session.
      programs.zsh.initContent = lib.mkAfter ''
        if [ -r "${config.age.secrets.ha-mcp-url.path}" ]; then
          export HOMEASSISTANT_MCP_URL="$(< "${config.age.secrets.ha-mcp-url.path}")"
        fi
      '';
      # Global Claude Code instructions
      home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
      # User-scope subagents — invoked by main Claude via the Agent tool with
      # subagent_type matching the `name:` field in each frontmatter.
      home.file.".claude/agents" = {
        source = ./agents;
        recursive = true;
      };
      # Install settings.json as a real mutable file instead of a Nix store
      # symlink. Claude Code does a write-test on settings.json at startup;
      # a read-only symlink causes the entire permission system to fall back
      # to asking for everything (upstream issue #3575).
      home.activation.claudeCodeSettings = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD rm -f "$HOME/.claude/settings.json"
        $DRY_RUN_CMD install -m 600 ${claudeSettingsFile} "$HOME/.claude/settings.json"
      '';
      # Merge user-scope MCP servers into ~/.claude.json (the documented
      # user-scope MCP location), preserving Claude Code's mutable state.
      home.activation.claudeCodeGlobalMcp = home-manager.lib.hm.dag.entryAfter ["claudeCodeSettings"] ''
        $DRY_RUN_CMD ${mergeGlobalMcpScript}
      '';
      programs.claude-code.enable = true;
    };
  };
}
