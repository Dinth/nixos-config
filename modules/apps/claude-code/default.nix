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
      nixpkgs.config.allowUnfree = true;
      home.packages = with pkgs; [
        yamlfmt
        php83Packages.php-cs-fixer
        shfmt
        shellcheck
        nodePackages.prettier
        djlint
        ruff
      ];
      # Global Claude Code instructions
      home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;
      programs.claude-code = {
        enable = true;
        settings = {
          theme = "catppuccin";
          respectGitignore = true;
          includeCoAuthoredBy = true;
          mcpServers = {
            nixos = {
              command = lib.getExe pkgs.mcp-nixos;
            };
            grafana = {
              url = "http://10.10.1.13:5133/mcp";
              transport = "sse";
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
              "Bash(nix log*)"
              # Safe file system operations
              "Bash(ls*)"
              "Bash(pwd*)"
              "Bash(find*)"
              "Bash(grep*)"
              "Bash(rg*)"
              "Bash(cat*)"
              "Bash(head*)"
              "Bash(tail*)"
              "Bash(mkdir*)"
              # Docker read-only
              "Bash(docker ps*)"
              "Bash(docker logs*)"
              "Bash(docker inspect*)"
              "Bash(docker images*)"
              "Bash(docker stats*)"
              "Bash(docker version*)"
              "Bash(docker info*)"
              # GitHub CLI read-only
              "Bash(gh pr list*)"
              "Bash(gh pr view*)"
              "Bash(gh issue list*)"
              "Bash(gh issue view*)"
              "Bash(gh repo view*)"
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
              "Bash(chmod*)"
              # System operations
              "Bash(sudo*)"
              "Bash(nixos-rebuild*)"
              # Network operations
              "Bash(curl*)"
              "Bash(wget*)"
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
