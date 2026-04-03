{
  config,
  lib,
  pkgs,
  home-manager,
  ...
}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;

  # Settings attrset — serialised to JSON and installed as a real mutable
  # file via home.activation (see below). programs.claude-code.settings
  # produces a read-only Nix store symlink which breaks Claude Code's
  # permission enforcement (upstream issue #3575).
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
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
    theme = "catppuccin";
    respectGitignore = true;
    includeCoAuthoredBy = true;
    mcpServers = {
      nixos.command = lib.getExe pkgs.mcp-nixos;
      homeassistant = {
        url = "http://10.10.1.11:9583/private_qkIKhBJAoLwsNLm-9D4tdg";
        transport = "streamable-http";
      };
      grafana = {
        url = "http://10.10.1.13:5133/mcp";
        transport = "http";
      };
      unifi = {
        url = "http://10.10.1.13:5134/sse";
        transport = "sse";
      };
    };
    permissions = {
      allow = [
        "Bash(git status*)" "Bash(git log*)" "Bash(git diff*)" "Bash(git show*)"
        "Bash(git branch*)" "Bash(git remote*)" "Bash(git config --get*)"
        "Bash(git config --list*)" "Bash(git rev-parse*)" "Bash(git ls-files*)"
        "Bash(git ls-remote*)" "Bash(git describe*)" "Bash(git tag --list*)"
        "Bash(git blame*)" "Bash(git shortlog*)" "Bash(git reflog*)"
        "Bash(nix search*)" "Bash(nix eval*)" "Bash(nix show-config*)"
        "Bash(nix flake show*)" "Bash(nix flake check*)" "Bash(nix flake info*)"
        "Bash(nix flake metadata*)" "Bash(nix log*)"
        "Bash(nix-instantiate --parse*)" "Bash(nix-instantiate --show-trace*)"
        "Bash(nh search*)"
        "Bash(ls*)" "Bash(pwd*)" "Bash(find*)" "Bash(grep*)" "Bash(rg*)"
        "Bash(cat*)" "Bash(head*)" "Bash(tail*)" "Bash(less*)" "Bash(wc*)"
        "Bash(sort*)" "Bash(uniq*)" "Bash(file*)" "Bash(stat*)" "Bash(tree*)"
        "Bash(eza*)" "Bash(mkdir*)" "Bash(chmod*)"
        "Bash(journalctl*)" "Bash(systemctl status*)" "Bash(systemctl is-active*)"
        "Bash(systemctl is-enabled*)" "Bash(systemctl list-units*)"
        "Bash(systemctl list-unit-files*)" "Bash(systemctl list-timers*)"
        "Bash(systemctl show*)" "Bash(dmesg*)" "Bash(uname*)" "Bash(hostname*)"
        "Bash(whoami*)" "Bash(id*)" "Bash(which*)" "Bash(type*)" "Bash(date*)"
        "Bash(uptime*)" "Bash(df*)" "Bash(du*)" "Bash(free*)" "Bash(lsblk*)"
        "Bash(lsusb*)" "Bash(lspci*)" "Bash(env*)"
        "Bash(ip addr*)" "Bash(ip route*)" "Bash(ip link*)" "Bash(ss*)"
        "Bash(ps*)" "Bash(pgrep*)" "Bash(pactl list*)" "Bash(pw-top*)"
        "Bash(lpstat*)" "Bash(lpinfo*)" "Bash(qdbus*)"
        "Bash(docker ps*)" "Bash(docker logs*)" "Bash(docker inspect*)"
        "Bash(docker images*)" "Bash(docker stats*)" "Bash(docker version*)"
        "Bash(docker info*)" "Bash(docker network ls*)" "Bash(docker network inspect*)"
        "Bash(docker volume ls*)" "Bash(docker volume inspect*)"
        "Bash(gh pr list*)" "Bash(gh pr view*)" "Bash(gh issue list*)"
        "Bash(gh issue view*)" "Bash(gh repo view*)" "Bash(gh api*)"
        "WebSearch" "WebFetch"
        "mcp__nixos__home_manager_options_by_prefix"
        "Read(/home/${primaryUsername}/.claude/**)"
        "Read(/home/${primaryUsername}/.config/opencode/**)"
      ];
      ask = [
        "Bash(git config*)" "Bash(git add*)" "Bash(git reset*)" "Bash(git commit*)"
        "Bash(git push*)" "Bash(git pull*)" "Bash(git merge*)" "Bash(git rebase*)"
        "Bash(git checkout*)" "Bash(git switch*)" "Bash(git stash*)"
        "Bash(rm*)" "Bash(mv*)" "Bash(cp*)"
        "Bash(kill*)" "Bash(killall*)" "Bash(pkill*)"
        "Bash(sudo*)" "Bash(nixos-rebuild*)"
        "Bash(ping*)" "Bash(curl*)" "Bash(wget*)" "Bash(ssh*)" "Bash(scp*)" "Bash(rsync*)"
        "Bash(systemctl start*)" "Bash(systemctl stop*)" "Bash(systemctl restart*)"
        "Bash(systemctl reload*)" "Bash(systemctl enable*)" "Bash(systemctl disable*)"
        "Bash(docker compose*)" "Bash(docker run*)" "Bash(docker stop*)"
        "Bash(gh pr create*)" "Bash(gh issue create*)"
      ];
      deny = [
        "Read(.env)" "Read(**/secrets/*)" "Read(**/*.key)" "Read(**/*.pem)"
      ];
    };
  };

  claudeSettingsFile = pkgs.runCommand "claude-code-settings.json" { } ''
    ${lib.getExe pkgs.jq} '.' \
      ${pkgs.writeText "claude-settings-raw.json" (builtins.toJSON claudeSettings)} \
      > $out
  '';

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
in
{
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
      home.activation.claudeCodeSettings = home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD rm -f "$HOME/.claude/settings.json"
        $DRY_RUN_CMD install -m 600 ${claudeSettingsFile} "$HOME/.claude/settings.json"
      '';
      programs.claude-code.enable = true;
    };
  };
}
