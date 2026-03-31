{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;

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
      programs.claude-code = {
        enable = true;
        settings = {
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
            nixos = {
              command = lib.getExe pkgs.mcp-nixos;
            };
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
              # Non-destructive git commands
              "Bash(git status*)"
              "Bash(git log*)"
              "Bash(git diff*)"
              "Bash(git show*)"
              "Bash(git branch*)"
              "Bash(git remote*)"
              "Bash(git config --get*)"
              "Bash(git config --list*)"
              "Bash(git rev-parse*)"
              "Bash(git ls-files*)"
              "Bash(git ls-remote*)"
              "Bash(git describe*)"
              "Bash(git tag --list*)"
              "Bash(git blame*)"
              "Bash(git shortlog*)"
              "Bash(git reflog*)"
              # Safe Nix commands
              "Bash(nix search*)"
              "Bash(nix eval*)"
              "Bash(nix show-config*)"
              "Bash(nix flake show*)"
              "Bash(nix flake check*)"
              "Bash(nix flake info*)"
              "Bash(nix flake metadata*)"
              "Bash(nix log*)"
              "Bash(nix-instantiate --parse*)"
              "Bash(nix-instantiate --show-trace*)"
              "Bash(nh search*)"
              # Safe file system operations
              "Bash(ls*)"
              "Bash(pwd*)"
              "Bash(find*)"
              "Bash(grep*)"
              "Bash(rg*)"
              "Bash(cat*)"
              "Bash(head*)"
              "Bash(tail*)"
              "Bash(less*)"
              "Bash(wc*)"
              "Bash(sort*)"
              "Bash(uniq*)"
              "Bash(file*)"
              "Bash(stat*)"
              "Bash(tree*)"
              "Bash(eza*)"
              "Bash(mkdir*)"
              "Bash(chmod*)"
              # System info commands (read-only)
              "Bash(journalctl*)"
              "Bash(systemctl status*)"
              "Bash(systemctl is-active*)"
              "Bash(systemctl is-enabled*)"
              "Bash(systemctl list-units*)"
              "Bash(systemctl list-unit-files*)"
              "Bash(systemctl list-timers*)"
              "Bash(systemctl show*)"
              "Bash(dmesg*)"
              "Bash(uname*)"
              "Bash(hostname*)"
              "Bash(whoami*)"
              "Bash(id*)"
              "Bash(which*)"
              "Bash(type*)"
              "Bash(date*)"
              "Bash(uptime*)"
              "Bash(df*)"
              "Bash(du*)"
              "Bash(free*)"
              "Bash(lsblk*)"
              "Bash(lsusb*)"
              "Bash(lspci*)"
              "Bash(env*)"
              # Network info (read-only)
              "Bash(ip addr*)"
              "Bash(ip route*)"
              "Bash(ip link*)"
              "Bash(ss*)"
              "Bash(ss -tulpn*)"
              # Process info (read-only)
              "Bash(ps*)"
              "Bash(pgrep*)"
              # Audio system (read-only)
              "Bash(pactl list*)"
              "Bash(pw-top*)"
              # Docker read-only
              "Bash(docker ps*)"
              "Bash(docker logs*)"
              "Bash(docker inspect*)"
              "Bash(docker images*)"
              "Bash(docker stats*)"
              "Bash(docker version*)"
              "Bash(docker info*)"
              "Bash(docker network ls*)"
              "Bash(docker network inspect*)"
              "Bash(docker volume ls*)"
              "Bash(docker volume inspect*)"
              # GitHub CLI read-only
              "Bash(gh pr list*)"
              "Bash(gh pr view*)"
              "Bash(gh issue list*)"
              "Bash(gh issue view*)"
              "Bash(gh repo view*)"
              "Bash(gh api*)"
              # Web tools
              "WebSearch"
              "WebFetch"
            ];
            ask = [
              # Git config changes
              "Bash(git config*)"
              "Bash(git add*)"
              # Potentially destructive git commands
              "Bash(git reset*)"
              "Bash(git commit*)"
              "Bash(git push*)"
              "Bash(git pull*)"
              "Bash(git merge*)"
              "Bash(git rebase*)"
              "Bash(git checkout*)"
              "Bash(git switch*)"
              "Bash(git stash*)"
              # File operations
              "Bash(rm*)"
              "Bash(mv*)"
              "Bash(cp*)"
              # Process management
              "Bash(kill*)"
              "Bash(killall*)"
              "Bash(pkill*)"
              # System operations
              "Bash(sudo*)"
              "Bash(nixos-rebuild*)"
              # Network operations
              "Bash(ping*)"
              "Bash(curl*)"
              "Bash(wget*)"
              "Bash(ssh*)"
              "Bash(scp*)"
              "Bash(rsync*)"
              # systemctl mutations
              "Bash(systemctl start*)"
              "Bash(systemctl stop*)"
              "Bash(systemctl restart*)"
              "Bash(systemctl reload*)"
              "Bash(systemctl enable*)"
              "Bash(systemctl disable*)"
              # Docker mutations
              "Bash(docker compose*)"
              "Bash(docker run*)"
              "Bash(docker stop*)"
              # GitHub CLI mutations
              "Bash(gh pr create*)"
              "Bash(gh issue create*)"
            ];
            deny = [
              # Prevent reading sensitive files
              "Read(.env)"
              "Read(**/secrets/*)"
              "Read(**/*.key)"
              "Read(**/*.pem)"
            ];
          };
        };
      };
    };
  };
}
