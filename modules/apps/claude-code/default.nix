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
      type = "sse";
      url = "http://10.10.1.13:5133/mcp";
    };
    unifi = {
      type = "sse";
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
    };

    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = toString rtkHookScript;
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
        "Bash(df:*)"
        "Bash(du:*)"
        "Bash(free:*)"
        "Bash(lsblk:*)"
        "Bash(lsusb:*)"
        "Bash(lspci:*)"
        "Bash(env:*)"
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
        # Web + curated MCP tools
        "WebSearch"
        "WebFetch"
        "mcp__nixos__home_manager_options_by_prefix"
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
      ];

      # Project-relative deny patterns need the `./` prefix to match.
      deny = [
        "Read(./.env)"
        "Read(./.env.*)"
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
  # context-usage bar + cost on line 2. Catppuccin-ish ANSI palette.
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline.sh";
    runtimeInputs = with pkgs; [jq git coreutils];
    text = ''
      input=$(cat)

      model=$(jq -r '.model.display_name // .model.id // "?"'         <<<"$input")
      dir=$(jq   -r '.workspace.current_dir // .cwd // "."'            <<<"$input")
      pct_raw=$(jq -r '.context_window.used_percentage // 0'           <<<"$input")
      cost=$(jq -r '.cost.total_cost_usd // 0'                         <<<"$input")
      effort=$(jq -r '.effort.level // empty'                          <<<"$input")
      thinking=$(jq -r 'if .thinking.enabled then "↯" else "" end'     <<<"$input")
      vim_mode=$(jq -r '.vim.mode // empty'                            <<<"$input")

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

      printf '%s\n%s' "$line1" "$line2"
    '';
  };

  # RTK rewrite hook script for Claude Code
  rtkHookScript = pkgs.writeShellScript "rtk-rewrite-hook.sh" ''
    # Read the tool input JSON from environment
    COMMAND=$(echo "$CLAUDE_TOOL_INPUT" | ${lib.getExe pkgs.jq} -r '.command // empty')

    if [ -z "$COMMAND" ]; then
      exit 0
    fi

    # Try to rewrite the command through RTK
    REWRITTEN=$(${lib.getExe pkgs.rtk} rewrite "$COMMAND" 2>/dev/null) || exit 0

    # If rtk gave us a rewritten command, output the modified tool input
    if [ -n "$REWRITTEN" ]; then
      echo "$CLAUDE_TOOL_INPUT" | ${lib.getExe pkgs.jq} --arg cmd "$REWRITTEN" '.command = $cmd'
      exit 0
    fi

    exit 0
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
      # Global Claude Code instructions
      home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
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
