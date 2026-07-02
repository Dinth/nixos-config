{
  config,
  lib,
  pkgs,
  home-manager,
  ...
}: let
  inherit (lib) mkIf;
  # Gated by the shared agenticAi toggle (defined in modules/apps/opencode),
  # so claude-code is enabled alongside opencode rather than depending on an
  # option named after the other tool.
  cfg = config.agenticAi;
  primaryUsername = config.primaryUser.name;
  userHome = "/home/${primaryUsername}";

  # Per-project settings overlays — merged into each project's
  # .claude/settings.local.json at activation time, preserving any
  # existing keys (other permissions, enabledMcpjsonServers, etc.).
  # Keyed by absolute project path. Use for machine-specific paths
  # like sshfs mounts that don't belong in the committed settings.json.
  projectOverrides = {
    "${userHome}/Documents/komodo_library" = {
      permissions.additionalDirectories = [
        "/mnt/omv/opt/docker"
      ];
    };
    # HAOS /config share (CIFS //10.10.1.11/config). Pre-approve the
    # project-scoped homeassistant MCP server so it loads without a trust
    # prompt. The `.mcp.json` itself is dropped here by claudeCodeHaosMarkers.
    "/mnt/haos" = {
      enabledMcpjsonServers = ["homeassistant"];
    };
    "/mnt/haos/esphome" = {
      enabledMcpjsonServers = ["homeassistant"];
    };
  };

  # HAOS marker files written into the CIFS share at activation (the share
  # lives outside $HOME so home.file can't manage it). `.mcp.json` wires the
  # write-capable homeassistant MCP at /mnt/haos and /mnt/haos/esphome; the
  # project CLAUDE.md flips Claude into HA mode whenever cwd is under the share.
  haosMcpJson = ./haos/mcp.json;
  haosClaudeMd = ./haos/CLAUDE.md;

  # Project paths seeded as trusted in ~/.claude.json. Claude Code 2.1+
  # ignores a project's settings.local.json permissions AND re-prompts for
  # its .mcp.json servers until the folder is explicitly trusted
  # (projects.<path>.hasTrustDialogAccepted). Every project we manage
  # declaratively must therefore also be trusted here — otherwise a fresh
  # checkout or new machine drops all the Nix-declared allow/MCP overlays and
  # prompts on first launch. Add new project roots here as they gain overlays.
  trustedProjects = lib.unique (
    builtins.attrNames projectOverrides
    ++ [
      "${userHome}/Documents/nixos-config"
      "${userHome}/Documents/komodo_library"
      "${userHome}/.claude"
      "${userHome}/.config/opencode"
    ]
  );

  # User-scope MCP servers — merged into ~/.claude.json at activation time
  # (instead of settings.json, which is not the documented MCP location).
  # Project-scope servers live in .mcp.json at each project root.
  globalMcpServers = {
    grafana = {
      type = "http";
      url = "http://10.10.1.13:5133/mcp";
    };
    # Scope: Wi-Fi / access points ONLY. Routing/firewall lives on pfSense
    # (10.10.0.1), wired switching on the Dell PowerConnect 5548P (10.10.0.20) —
    # both via SSH, not UniFi. See the Network equipment section in CLAUDE.md.
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

      # Bash patterns come from libs/agent-permissions.nix so claude-code
      # and opencode stay in lockstep. Each base command expands to two
      # entries — the literal spelling and the `rtk <cmd>` mirror —
      # because RTK's PreToolUse hook rewrites every bash invocation to
      # `rtk <cmd>` and that rewritten form needs its own permission.
      allow =
        lib.concatMap (cmd: [
          "Bash(${cmd}:*)"
          "Bash(rtk ${cmd}:*)"
        ])
        config.agentPermissions.readOnlyBash
        ++ ["WebSearch" "WebFetch"]
        ++ config.agentPermissions.mcpReadOnly;

      ask =
        lib.concatMap (cmd: [
          "Bash(${cmd}:*)"
          "Bash(rtk ${cmd}:*)"
        ])
        config.agentPermissions.askBash;

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

  # Merges the managed user-scope MCP servers and project-trust seeds into
  # ~/.claude.json without touching other mutable state (OAuth tokens,
  # sessions, history). The trust reduce sets only the two flags on each
  # managed project, preserving any existing per-project keys.
  mergeGlobalClaudeJsonScript = pkgs.writeShellScript "merge-claude-global-json.sh" ''
    set -euo pipefail
    CLAUDE_JSON="$HOME/.claude.json"
    MCP_JSON=${lib.escapeShellArg (builtins.toJSON globalMcpServers)}
    TRUSTED_JSON=${lib.escapeShellArg (builtins.toJSON trustedProjects)}

    if [ ! -s "$CLAUDE_JSON" ]; then
      ${lib.getExe' pkgs.coreutils "install"} -m 600 /dev/null "$CLAUDE_JSON"
      echo '{}' > "$CLAUDE_JSON"
    fi

    TMP="$(${lib.getExe' pkgs.coreutils "mktemp"} "$CLAUDE_JSON.XXXXXX")"
    ${lib.getExe pkgs.jq} --argjson mcp "$MCP_JSON" --argjson trusted "$TRUSTED_JSON" '
      .mcpServers = ((.mcpServers // {}) + $mcp)
      | reduce $trusted[] as $p (.;
          .projects[$p] = ((.projects[$p] // {})
            + {hasTrustDialogAccepted: true, hasCompletedProjectOnboarding: true}))
    ' "$CLAUDE_JSON" > "$TMP"
    ${lib.getExe' pkgs.coreutils "mv"} "$TMP" "$CLAUDE_JSON"
    ${lib.getExe' pkgs.coreutils "chmod"} 600 "$CLAUDE_JSON"
  '';

  # Merges per-project settings overlays into each project's
  # .claude/settings.local.json without clobbering existing keys.
  # jq's `*` operator deep-merges objects (arrays are replaced, so
  # the Nix-declared list becomes the source of truth for those keys).
  # Skips projects whose directory doesn't exist yet.
  mergeProjectSettingsScript = pkgs.writeShellScript "merge-claude-project-settings.sh" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (projectPath: overrides: ''
        if [ -d ${lib.escapeShellArg projectPath} ]; then
          SETTINGS=${lib.escapeShellArg "${projectPath}/.claude/settings.local.json"}
          NEW=${lib.escapeShellArg (builtins.toJSON overrides)}
          ${lib.getExe' pkgs.coreutils "mkdir"} -p ${lib.escapeShellArg "${projectPath}/.claude"}
          if [ ! -s "$SETTINGS" ]; then
            echo '{}' > "$SETTINGS"
          fi
          TMP="$(${lib.getExe' pkgs.coreutils "mktemp"} "$SETTINGS.XXXXXX")"
          ${lib.getExe pkgs.jq} --argjson new "$NEW" '. * $new' \
            "$SETTINGS" > "$TMP"
          ${lib.getExe' pkgs.coreutils "mv"} "$TMP" "$SETTINGS"
        fi
      '')
      projectOverrides)}
  '';

  # Drops the HA marker files onto the CIFS share. Guarded by `[ -d ]` (which
  # also triggers the autofs automount); writes are best-effort so a rebuild
  # never fails when HAOS is unreachable. `.mcp.json` carries the literal
  # ${HOMEASSISTANT_MCP_URL} placeholder — Claude Code expands it from the env
  # at launch, so the auth-keyed URL never lands on disk.
  mergeHaosMarkersScript = pkgs.writeShellScript "write-claude-haos-markers.sh" ''
    set -euo pipefail
    cp=${lib.getExe' pkgs.coreutils "cp"}
    for d in /mnt/haos /mnt/haos/esphome; do
      if [ -d "$d" ]; then
        "$cp" -f ${haosMcpJson} "$d/.mcp.json" || true
      fi
    done
    if [ -d /mnt/haos ]; then
      "$cp" -f ${haosClaudeMd} /mnt/haos/CLAUDE.md || true
    fi
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
        prettier
        djlint
        ruff
        rtk # Rust Token Killer - reduces LLM token consumption
      ];
      # Export HOMEASSISTANT_MCP_URL for the project-scope .mcp.json files on the
      # HA config share (/mnt/haos, /mnt/haos/esphome). The URL contains a private
      # auth key so it lives in ragenix; read at shell startup so it's available
      # whenever `claude` is launched from a zsh session.
      programs.zsh.initContent = lib.mkAfter ''
        if [ -r "${config.age.secrets.ha-mcp-url.path}" ]; then
          export HOMEASSISTANT_MCP_URL="$(< "${config.age.secrets.ha-mcp-url.path}")"
        fi
      '';
      # Register the claude-cli:// URL scheme handler declaratively. Claude Code
      # adds this to mimeapps.list at runtime, but once home-manager owns the
      # file it becomes a read-only store symlink the app can no longer write,
      # so the association has to be declared here to persist.
      xdg.mimeApps = {
        defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
        associations.added."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };
      # Global Claude Code instructions
      home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
      # User-scope subagents — invoked by main Claude via the Agent tool with
      # subagent_type matching the `name:` field in each frontmatter.
      home.file.".claude/agents" = {
        source = ./agents;
        recursive = true;
      };
      # User-scope skills — auto-activated by description match (e.g. the
      # home-assistant workflow skill).
      home.file.".claude/skills" = {
        source = ./skills;
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
      # Merge user-scope MCP servers + project-trust seeds into ~/.claude.json
      # (the documented user-scope MCP location), preserving Claude Code's
      # mutable state.
      home.activation.claudeCodeGlobalJson = home-manager.lib.hm.dag.entryAfter ["claudeCodeSettings"] ''
        $DRY_RUN_CMD ${mergeGlobalClaudeJsonScript}
      '';
      # Merge Nix-declared per-project overlays into each project's
      # .claude/settings.local.json. Used for machine-specific paths
      # (e.g. sshfs mounts) that don't belong in committed settings.json.
      home.activation.claudeCodeProjectSettings = home-manager.lib.hm.dag.entryAfter ["claudeCodeGlobalJson"] ''
        $DRY_RUN_CMD ${mergeProjectSettingsScript}
      '';
      # Drop the HA marker files (.mcp.json + CLAUDE.md) onto the /mnt/haos CIFS
      # share so working there auto-loads HA mode + the homeassistant MCP.
      home.activation.claudeCodeHaosMarkers = home-manager.lib.hm.dag.entryAfter ["claudeCodeProjectSettings"] ''
        $DRY_RUN_CMD ${mergeHaosMarkersScript}
      '';
      programs.claude-code.enable = true;
    };
  };
}
