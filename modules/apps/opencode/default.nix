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
      home.file.".config/opencode/knowledge/infrastructure.md".source = ./knowledge/infrastructure.md;
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
          agent = {
            manager = {
              mode = "primary";
              model = "google/gemini-2.5-pro";
              # model = "opencode/claude-sonnet-4-5";
              prompt = ''
                You are the Technical Project Manager. Analyze user intent and delegate to specialists. For complex web research, use @procurement. For NixOS configuration, use @nixos-engineer.
              '';
              temperature = 0.3;
              topP = 0.9;
              topK = 40;
              maxTokens = 4096;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
#               delegation = {
#                 maxDelegationDepth = 3;
#                 delegationTimeout = 300000;
#                 allowedSubagents = [
#                   "nixos-engineer",
#                   "polyglot-coder",
#                   "procurement",
#                   "triage-specialist",
#                   "infra-manager",
#                   "home-assistant-agent",
#                   "docs-specialist",
#                   "secops"
#                 ];
#               };
              caching = {
                enabled = true;
                ttl = 600;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
              };
#               fallbackModels = [
#                 "google/gemini-3-pro-preview",
#                 "opencode/gpt-5.2",
#                 "opencode/gemini-3-pro",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload"];
            };
            procurement = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              prompt = ''
                You are a Procurement & Research Specialist.
                - Use @web-extractor to pull structured data.
                - Iteratively search until exact dimensions/specs are verified.
                - Provide a final comparison table with 'Confidence Scores'.
              '';
              temperature = 0.5;
              topP = 0.92;
              topK = 50;
              maxTokens = 8192;
              frequencyPenalty = 0.2;
              presencePenalty = 0.1;
              caching = {
                enabled = true;
                ttl = 300;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
              };
#               fallbackModels = [
#                 "opencode/gemini-3-flash",
#                 "google/gemini-2.5-pro",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            web-extractor = {
              mode = "subagent";
              model = "google/gemini-2.5-flash";
              # model = "opencode/gemini-3-flash";
              prompt = "You are a Parsing Specialist. Convert raw HTML into clean JSON/Markdown. Discover API endpoints by inspecting source code.";
#              tools = ["firecrawl" "agentql"];
              temperature = 0.1;
              topP = 0.85;
              topK = 20;
              maxTokens = 4096;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
#               stopSequences = ["```json\n\n", "---END---"];
              caching = {
                enabled = true;
                ttl = 900;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
              };
#               fallbackModels = [
#                 "opencode/gemini-3-pro",
#                 "google/gemini-2.5-flash",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            triage-specialist = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/gemini-3-pro";
              prompt = ''
                You are the Triage Lead. Your job is to find the "Why".
                1. When a failure is reported, query Grafana/Loki for error logs.
                2. Correlate timestamps across different servers (Debian/Desktop).
                3. Provide a 'Root Cause Analysis' (RCA) to the Manager.
              '';
              tools = {
                grafana-mcp = true;
              };
              temperature = 0.2;
              topP = 0.85;
              topK = 30;
              maxTokens = 8192;
              frequencyPenalty = 0.3;
              presencePenalty = 0.1;
              caching = {
                enabled = true;
                ttl = 300;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "google/gemini-2.5-pro",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            docs-specialist = {
              mode = "subagent";
              model = "opencode/glm-4.7-free";
              prompt = ''
                You are the Librarian.
                - Your task is to maintain the `~/Documents/system_manual.md`.
                - Every time a script is added or a config is changed, record:
                  [Date] [Agent] [Change Summary] [Impacted Systems].
                - If the network inventory file changes, update the topology diagrams (Mermaid).
              '';
              tools = {
                filesystem = true;
              };
              temperature = 0.4;
              topP = 0.88;
              topK = 35;
              maxTokens = 4096;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
              caching = {
                enabled = true;
                ttl = 1200;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "google/gemini-2.5-flash",
#                 "opencode/kimi-k2.5-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            nixos-engineer = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/claude-sonnet-4-5";
              prompt = ''
                You are a NixOS Specialist.
                - Your goal is to maintain the system closure in /etc/nixos.
                - When a task requires a custom script (Bash/Python/PHP), DELEGATE the script generation to @polyglot-coder.
                - Once @polyglot-coder provides the script, wrap it in a Nix expression (like `pkgs.writeShellScriptBin` or `virtualisation.oci-containers`).
                - Always run `nix-instantiate --parse` or `nixpkgs-fmt` on your output.
                ERROR HANDLING:
                - If a Nix build fails, run `nix-instantiate --show-trace` for detailed errors
                - Check syntax with `nix-instantiate --parse` before committing changes
                - On attribute errors, verify package availability with `nix search`
              '';
              temperature = 0.2;
              topP = 0.85;
              topK = 25;
              maxTokens = 8192;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
#               stopSequences = ["};\n\n\n", "# END OF CONFIG"];
#               delegation = {
#                 maxDelegationDepth = 2;
#                 allowedSubagents = ["polyglot-coder", "docs-specialist"];
#                 mustDelegateFor = ["bash-script", "python-script", "php-script"];
#               };
              tools = {
                filesystem = true;
                bash = true;
                nixos-mcp = true;
              };
              caching = {
                enabled = true;
                ttl = 900;
                cacheSystemPrompt = true;
                cacheKnowledge = true;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "google/gemini-3-pro-preview",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            home-assistant-agent = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/claude-sonnet-4-5";
              prompt = ''
                You are an IoT Specialist.
                - You write Home Assistant YAML and ESPHome configs.
                - You prioritize local-push over cloud-poll for latency.
                - If an automation fails, ask @triage-specialist for the specific error trace.
                - When formatting, prioritize `djlint` for any files containing `{{` or `{%` blocks.
                - JINJA2: Ensure all templates have default values (e.g., `states('sensor.temp') | float(0)`) to prevent boot-looping HA.
                '';
              temperature = 0.3;
              topP = 0.88;
              topK = 30;
              maxTokens = 4096;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
#               stopSequences = ["---\n\n", "# END"];
              tools = {
#                home-assistant-mcp = true;
              };
              caching = {
                enabled = true;
                ttl = 600;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
              };
#               fallbackModels = [
#                 "google/gemini-3-pro-preview",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            infra-manager = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/gemini-3-pro";
              prompt = ''
                You are the Network Custodian.
                - READ first: Always consult `{file:~/.config/opencode/knowledge/infrastructure.md}` to locate devices.
                - SSH ACCESS: Use the `ssh-mcp` tool for Debian/pfSense.
                - CONTEXT: You know that only the Desktop is NixOS; others are Debian/Unifi/ESPHome.
              '';
              temperature = 0.4;
              topP = 0.9;
              topK = 40;
              maxTokens = 8192;
              frequencyPenalty = 0.1;
              presencePenalty = 0.1;
              tools = {
                ssh-mcp = true;
                filesystem = true;
              };
              caching = {
                enabled = true;
                ttl = 600;
                cacheSystemPrompt = true;
                cacheKnowledge = true;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "google/gemini-3-pro-preview",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            polyglot-coder = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/gpt-5.2-codex";
              prompt = ''
                You are an Expert Software Engineer specializing in Bash, Python 3 and PHP 8.3+.
                - BASH: Use 'set -euo pipefail', local variables, and prioritize readability. Always assume `shellcheck` will be run.
                - PYTHON: Prioritize type hinting and use standard libraries unless specialized ones are requested.
                - PHP: Use modern 8.3 features, strict typing, and clean architectural patterns.
                - TASK: When writing scripts that parse data, check if @web-extractor has data available first.
                - Output ONLY the code and a brief explanation of how to execute it.
              '';
              skills = [ "coding-standards" ];
              temperature = 0.1;
              topP = 0.1;
              topK = 10;
              maxTokens = 8192;
              frequencyPenalty = 0.0;
              presencePenalty = 0.0;
              tools = {
                bash = true;
              };
              caching = {
                enabled = true;
                ttl = 1800;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
                cacheSkills = true;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "opencode/gpt-5.1-codex",
#                 "google/gemini-3-pro-preview",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
            secops = {
              mode = "subagent";
              model = "google/gemini-2.5-pro";
              # model = "opencode/claude-opus-4-5";
              prompt = "Ethical Hacker. Perform pentesting (ZAP/Nmap), risk modelling, and gather threat intelligence. Map findings to CVEs.";
              temperature = 0.4;
              topP = 0.9;
              topK = 40;
              maxTokens = 8192;
              frequencyPenalty = 0.2;
              presencePenalty = 0.15;
              caching = {
                enabled = true;
                ttl = 900;
                cacheSystemPrompt = true;
                cacheKnowledge = false;
                cacheToolDefinitions = true;
              };
#               fallbackModels = [
#                 "gemini-3-pro-preview",
#                 "opencode/claude-sonnet-4-5",
#                 "opencode/glm-4.7-free"
#               ];
#               fallbackOnErrors = ["rate_limit", "timeout", "overload", "service_unavailable"];
            };
          };
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
            nixfmt = {
              command = [
                (lib.getExe pkgs.nixfmt)
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
              command = [ "(lib.getExe pkgs.yamlfmt)" "$FILE" ];
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
