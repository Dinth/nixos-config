{ config, lib, pkgs, ...}:
let
  inherit (lib) mkIf mkOption;
  cfg = config.opencode;
  primaryUsername = config.primaryUser.name;
in
{
  options = {
    opencode = {
      enable = mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install opencode.";
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
        mcp-nixos
        djlint
        ruff
      ];
      # Knowledge files — split by topic, loaded per-agent to avoid wasting context
      home.file.".config/opencode/knowledge/hosts.md".source         = ./knowledge/hosts.md;
      home.file.".config/opencode/knowledge/docker.md".source        = ./knowledge/docker.md;
      home.file.".config/opencode/knowledge/homeassistant.md".source = ./knowledge/homeassistant.md;
      home.file.".config/opencode/knowledge/nixos.md".source         = ./knowledge/nixos.md;
      home.file.".config/opencode/skills" = {
        source = ./skills;
        recursive = true;
      };
      home.sessionVariables = {
        OPENCODE_LOG_LEVEL = "debug"; # Force debug logging at env level
#        OPENCODE_METRICS_ENABLED = "true";
#        OPENCODE_METRICS_ENDPOINT = "http://10.10.1.13:9090/metrics";  # Prometheus - to add
      };
      programs.opencode = {
        enable = true;
        settings = {
          theme = "catppuccin";
          provider = {
            opencode = {
#               timeout = 120000;
#               retryAttempts = 3;
#               retryDelay = 1000;
#               retryExponentialBase = 2.0;
#               retryJitter = true;
#               maxRetryDelay = 60000;
            };
            google = {
#               timeout = 120000;
#               retryAttempts = 3;
#               retryDelay = 1000;
#               retryExponentialBase = 2.0;
#               retryJitter = true;
#               maxRetryDelay = 60000;
            };
            ollama = {
              name = "Ollama (10.10.1.13)";
              npm = "@ai-sdk/openai-compatible";
              options = { baseURL = "http://10.10.1.13:11434/v1"; };
#               timeout = 240000;  # 3 minutes - local models can be slower
#               retryAttempts = 2;  # Fewer retries for local server
#               retryDelay = 500;
#               retryExponentialBase = 1.5;
#               maxRetryDelay = 5000;
              models = {
                "gpt-oss:20b" = { name = "GPT-OSS 20B"; tools = true; };
                "mistral-nemo:latest" = { name = "Mistral Nemo"; tools = true; };
              };
            };
          };
#           rateLimit = {
#             enabled = true;
#             maxRequestsPerMinute = 30;
#             maxRequestsPerHour = 500;
#             maxTokensPerDay = 2000000;
#             costAlert = {
#               dailyThreshold = 10;  # Alert at $100/day
#               notificationEmail = "michal@gawronskikot.com";
#             };
#           };
          watcher.ignore = [
            ".git/**"
            ".direnv/**"
            "node_modules/**"
            "dist/**"
            "target/**"
            "result/**"
            "__pycache__/**"      # Python cache
            "*.pyc"               # Compiled Python
            ".venv/**"            # Python virtual envs
            ".pytest_cache/**"    # Pytest cache
            ".mypy_cache/**"      # Type checking cache
            "vendor/**"           # PHP/composer dependencies
            ".home-assistant/**"  # HA runtime data (if editing in place)
          ];
          agent = import ./agents.nix;
          plugin = [
            # "opencode-gemini-auth@latest"
            "opencode-google-antigravity-auth@latest"
            "@tarquinen/opencode-dcp@latest"
            "@mohak34/opencode-notifier@latest"
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

              # Safe system info commands
              "systemctl list-units*" = "allow";
              "systemctl list-timers*" = "allow";
              "systemctl status*" = "allow";
              "journalctl*" = "allow";
              "dmesg*" = "allow";
              "env*" = "allow";
              "nh search*" = "allow";

              # Audio system (read-only)
              "pactl list*" = "allow";
              "pw-top*" = "allow";

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

              # System control operations
              "systemctl start*" = "ask";
              "systemctl stop*" = "ask";
              "systemctl restart*" = "ask";
              "systemctl reload*" = "ask";
              "systemctl enable*" = "ask";
              "systemctl disable*" = "ask";

              # Network operations
              "curl*" = "ask";
              "wget*" = "ask";
              "ping*" = "ask";
              "ssh*" = "ask";
              "scp*" = "ask";
              "rsync*" = "ask";

              # Package management
              "sudo*" = "ask";
              "nixos-rebuild*" = "ask";

              # Process management
              "kill*" = "ask";
              "killall*" = "ask";
              "pkill*" = "ask";

              # Docker management
              "docker ps*" = "allow";
              "docker logs*" = "allow";
              "docker inspect*" = "allow";
              "docker compose*" = "ask";
              "docker images*" = "allow";
              "docker stats*" = "allow";
              "docker version*" = "allow";
              "docker info*" = "allow";
              "docker network ls*" = "allow";
              "docker volume ls*" = "allow";
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
              command = [ (lib.getExe pkgs.yaml-language-server) "--stdio" ];
              extensions = [ ".yaml" ".yml" ];
            };
            php = {
              command = [ (lib.getExe pkgs.phpactor) "language-server" ];
              extensions = [ ".php" ];
            };
            bash = {
              command = [ (lib.getExe pkgs.bash-language-server) "start" ];
              extensions = [ ".sh" ".bash" ];
            };
            python = {
              command = [ (lib.getExe pkgs.pyright) "--stdio" ];
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
              command = [ (lib.getExe pkgs.nodePackages.prettier) "--parser" "json" "$FILE" ];
              extensions = [ ".json" ];
            };
            djlint = {
              command = [
                "${pkgs.djlint}/bin/djlint"
                "$FILE"
                "--reformat"
                "--indent" "2"
              ];
              extensions = [ ".html" ".jinja" ".jinja2" ".j2" ];
            };
            yamlfmt = {
              command = [ (lib.getExe pkgs.yamlfmt) "$FILE" ];
              extensions = [ ".yaml" ".yml" ];
            };
            python = {
              command = [ (lib.getExe pkgs.ruff) "format" "$FILE" ];
              extensions = [ ".py" ];
            };
          };
          mcp = {
            grafana = {
              type = "remote";
              url = "http://10.10.1.13:5133/mcp";
              enabled = true;
               timeout = 30000;
#               retryAttempts = 3;
#               retryDelay = 1000;
#               circuitBreaker = {
#                 enabled = true;
#                 failureThreshold = 5;
#                 recoveryTimeout = 60;
#               };
            };
            unifi = {
              type = "remote";
              url = "http://10.10.1.13:5134/sse";
              enabled = true;
               timeout = 20000;
#               retryAttempts = 3;
#               retryDelay = 1000;
#               headers = {
#                 Accept = "text/event-stream";
#               };
#               circuitBreaker = {
#                 enabled = true;
#                 failureThreshold = 3;
#                 recoveryTimeout = 30;
#               };
            };
            nixos = {
              enabled = true;
              type = "local";
              command = [ (lib.getExe pkgs.mcp-nixos) ];
              timeout = 15000;
            };
          };
        };
      };
    };
  };
}
