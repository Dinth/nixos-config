{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.claude-code;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    claude-code = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install claude-code.";
      };
    };
  };
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
      # Re-adding mcp-nixos as it is crucial for NixOS maintenance
      # Adding nom for better build log analysis
      nix-output-monitor
    ];
    home-manager.users.${primaryUsername} = {
      home.packages = with pkgs; [
        yamlfmt
        php83Packages.php-cs-fixer
        shfmt
        libxml2
        yaml-language-server
        phpactor
        bash-language-server
        pyright
        lemminx
        shellcheck
        nodePackages.prettier
        djlint
        ruff
      ];
      # Knowledge files — split by topic, loaded per-agent to avoid wasting context
      home.file.".config/claude-code/knowledge/hosts.md".source = ./knowledge/hosts.md;
      home.file.".config/claude-code/knowledge/docker.md".source = ./knowledge/docker.md;
      home.file.".config/claude-code/knowledge/homeassistant.md".source = ./knowledge/homeassistant.md;
      home.file.".config/claude-code/knowledge/nixos.md".source = ./knowledge/nixos.md;
      home.file.".config/claude-code/skills" = {
        source = ./skills;
        recursive = true;
      };
      home.sessionVariables = {
        CLAUDE_CODE_LOG_LEVEL = "debug"; # Force debug logging at env level
      };
      programs.claude-code = {
        enable = true;
        settings = {
          theme = "catppuccin";
          provider = {
            claude = {
              # timeout = 120000;
              # retryAttempts = 3;
              # retryDelay = 1000;
              # retryExponentialBase = 2.0;
              # retryJitter = true;
              # maxRetryDelay = 60000;
            };
            google = {
              # timeout = 120000;
              # retryAttempts = 3;
              # retryDelay = 1000;
              # retryExponentialBase = 2.0;
              # retryJitter = true;
              # maxRetryDelay = 60000;
            };
          };
          watcher.ignore = [
            ".git/**"
            ".direnv/**"
            "node_modules/**"
            "dist/**"
            "target/**"
            "result/**"
            "__pycache__/**" # Python cache
            "*.pyc" # Compiled Python
            ".venv/**" # Python virtual envs
            ".pytest_cache/**" # Pytest cache
            ".mypy_cache/**" # Type checking cache
            "vendor/**" # PHP/composer dependencies
            ".home-assistant/**" # HA runtime data (if editing in place)
          ];
          agent = import ./agents.nix;
          plugin = [
            # Add any relevant plugins for claude-code here
          ];
          permission = {
            bash = {
              # Allow non-destructive git commands with wildcards
              "git status*" = "allow";
              "git log*" = "allow";
              "git diff*" = "allow";
              "git show*" = "allow";
              "git branch*" = "allow";
              "git remote*" = "allow";
              "git config --get*" = "allow";
              "git config --list*" = "allow";
              "git config --global*" = "ask";
              "git config*" = "ask";
              "git rev-parse*" = "allow";
              "git ls-files*" = "allow";
              "git ls-remote*" = "allow";
              "git describe*" = "allow";
              "git tag --list*" = "allow";
              "git blame*" = "allow";
              "git shortlog*" = "allow";
              "git reflog*" = "allow";
              "git add*" = "ask";

              # Safe Nix commands
              "nix search*" = "allow";
              "nix eval*" = "allow";
              "nix show-config*" = "allow";
              "nix flake show*" = "allow";
              "nix flake check*" = "allow";
              "nix log*" = "allow";

              # Safe file system operations
              "ls*" = "allow";
              "pwd*" = "allow";
              "find*" = "allow";
              "grep*" = "allow";
              "rg*" = "allow";
              "cat*" = "allow";
              "head*" = "allow";
              "tail*" = "allow";
              "mkdir*" = "allow";
              "chmod*" = "allow";

              # Potentially destructive git commands
              "git reset*" = "ask";
              "git commit*" = "ask";
              "git push*" = "ask";
              "git pull*" = "ask";
              "git merge*" = "ask";
              "git rebase*" = "ask";
              "git checkout*" = "ask";
              "git switch*" = "ask";
              "git stash*" = "ask";

              # File deletion and modification
              "rm*" = "ask";
              "mv*" = "ask";
              "cp*" = "ask";
            };
            edit = "ask";
            read = "allow";
            context_info = "allow";
            list = "allow";
            glob = "allow";
            grep = "allow";
            webfetch = "ask";
            write = "ask";
            task = "allow";
            todowrite = "allow";
            todoread = "allow";
          };
          lsp = {
            yaml = {
              command = [
                (lib.getExe pkgs.yaml-language-server)
                "--stdio"
              ];
              extensions = [
                ".yaml"
                ".yml"
              ];
            };
            php = {
              command = [
                (lib.getExe pkgs.phpactor)
                "language-server"
              ];
              extensions = [ ".php" ];
            };
            bash = {
              command = [
                (lib.getExe pkgs.bash-language-server)
                "start"
              ];
              extensions = [
                ".sh"
                ".bash"
              ];
            };
            python = {
              command = [
                (lib.getExe pkgs.pyright)
                "--stdio"
              ];
              extensions = [ ".py" ];
            };
            xml = {
              command = [ (lib.getExe pkgs.lemminx) ];
              extensions = [ ".xml" ];
            };
          };
          formatter = {
            nixfmt-rfc-style = {
              command = [
                (lib.getExe pkgs.nixfmt-rfc-style)
                "$FILE"
              ];
              extensions = [ ".nix" ];
            };
            jsonc = {
              command = [
                (lib.getExe pkgs.nodePackages.prettier)
                "--parser"
                "json"
                "$FILE"
              ];
              extensions = [ ".json" ];
            };
            djlint = {
              command = [
                "${pkgs.djlint}/bin/djlint"
                "$FILE"
                "--reformat"
                "--indent"
                "2"
              ];
              extensions = [
                ".html"
                ".jinja"
                ".jinja2"
                ".j2"
              ];
            };
            yamlfmt = {
              command = [
                (lib.getExe pkgs.yamlfmt)
                "$FILE"
              ];
              extensions = [
                ".yaml"
                ".yml"
              ];
            };
            python = {
              command = [
                (lib.getExe pkgs.ruff)
                "format"
                "$FILE"
              ];
              extensions = [ ".py" ];
            };
          };
        };
      };
    };
  };
}
