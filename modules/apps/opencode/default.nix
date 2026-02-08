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
    programs.nix-ld.enable = true;
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
      ];
      home.sessionVariables = {
        OPENCODE_LOG_LEVEL = "debug"; # Force debug logging at env level
        # ensure it uses standard XDG paths
        XDG_DATA_HOME = "${config.home-manager.users.${primaryUsername}.home.homeDirectory}/.local/share";
      };
      programs.opencode = {
        enable = true;
        settings = {
          theme = "catppuccin";
          model = "ollama/mistral-nemo:latest";
          provider = {
            google = {
              models = {
                # Antigravity Gemini 3 Pro
                "antigravity-gemini-3-pro" = {
                  name = "Gemini 3 Pro (Antigravity)";
                  limit = {
                    context = 1048576;
                    output = 65535;
                  };
                  modalities = {
                    input = [
                      "text"
                      "image"
                      "pdf"
                    ];
                    output = [ "text" ];
                  };
                  variants = {
                    low = {
                      thinkingLevel = "low";
                    };
                    high = {
                      thinkingLevel = "high";
                    };
                  };
                };
                # Antigravity Gemini 3 Flash
                "antigravity-gemini-3-flash" = {
                  name = "Gemini 3 Flash (Antigravity)";
                  limit = {
                    context = 1048576;
                    output = 65536;
                  };
                  modalities = {
                    input = [
                      "text"
                      "image"
                      "pdf"
                    ];
                    output = [ "text" ];
                  };
                  variants = {
                    minimal = {
                      thinkingLevel = "minimal";
                    };
                    low = {
                      thinkingLevel = "low";
                    };
                    medium = {
                      thinkingLevel = "medium";
                    };
                    high = {
                      thinkingLevel = "high";
                    };
                  };
                };
                # Antigravity Claude Sonnet 4.5
                "antigravity-claude-sonnet-4-5" = {
                  name = "Claude Sonnet 4.5 (Antigravity)";
                  limit = {
                    context = 200000;
                    output = 64000;
                  };
                  modalities = {
                    input = [
                      "text"
                      "image"
                      "pdf"
                    ];
                    output = [ "text" ];
                  };
                };
                # Antigravity Claude Sonnet 4.5 Thinking
                "antigravity-claude-sonnet-4-5-thinking" = {
                  name = "Claude Sonnet 4.5 Thinking (Antigravity)";
                  limit = {
                    context = 200000;
                    output = 64000;
                  };
                  modalities = {
                    input = [
                      "text"
                      "image"
                      "pdf"
                    ];
                    output = [ "text" ];
                  };
                  variants = {
                    low = {
                      thinkingConfig = {
                        thinkingBudget = 8192;
                      };
                    };
                    max = {
                      thinkingConfig = {
                        thinkingBudget = 32768;
                      };
                    };
                  };
                };
                # Antigravity Claude Opus 4.5 Thinking
                "antigravity-claude-opus-4-5-thinking" = {
                  name = "Claude Opus 4.5 Thinking (Antigravity)";
                  limit = {
                    context = 200000;
                    output = 64000;
                  };
                  modalities = {
                    input = [
                      "text"
                      "image"
                      "pdf"
                    ];
                    output = [ "text" ];
                  };
                  variants = {
                    low = {
                      thinkingConfig = {
                        thinkingBudget = 8192;
                      };
                    };
                    max = {
                      thinkingConfig = {
                        thinkingBudget = 32768;
                      };
                    };
                  };
                };
              };
            };
            ollama = {
              name = "Ollama (10.10.1.13)";
              npm = "@ai-sdk/openai-compatible";
              options = { baseURL = "http://10.10.1.13:11434/v1"; };
              models = {
                "gpt-oss:20b" = { name = "GPT-OSS 20B"; tools = true; };
                "mistral-nemo:latest" = { name = "Mistral Nemo"; tools = true; };
              };
            };
          };
          watcher.ignore = [
            ".git/**"
            ".direnv/**"
            "node_modules/**"
            "dist/**"
            "target/**"
            "result/**"
          ];
          agent = {
            manager = {
              mode = "primary";
              model = "anthropic/claude-3-5-sonnet-latest";
              prompt = ''
                You are the Technical Project Manager. Analyze user intent and delegate to specialists. For complex web research, use @procurement. For NixOS configuration, use @nixos-engineer.
              '';
            };
            procurement = {
              mode = "subagent";
              model = "google/gemini-1.5-pro-latest"; # Superior reasoning/context
              prompt = ''
                You are a Procurement & Research Specialist.
                - Use @web-extractor to pull structured data.
                - Iteratively search until exact dimensions/specs are verified.
                - Provide a final comparison table with 'Confidence Scores'.
              '';
            };
            web-extractor = {
              mode = "subagent";
              model = "google/gemini-1.5-flash-latest";
              prompt = "You are a Parsing Specialist. Convert raw HTML into clean JSON/Markdown. Discover API endpoints by inspecting source code.";
              tools = ["firecrawl" "agentql"];
            };
            nixos-engineer = {
              mode = "subagent";
              model = "anthropic/claude-3-5-sonnet-latest";
              prompt = ''
                You are a NixOS Specialist.
                - Your goal is to maintain the system closure in /etc/nixos.
                - When a task requires a custom script (Bash/Python/PHP), DELEGATE the script generation to @polyglot-coder.
                - Once @polyglot-coder provides the script, wrap it in a Nix expression (like `pkgs.writeShellScriptBin` or `virtualisation.oci-containers`).
                - Always run `nix-instantiate --parse` or `nixpkgs-fmt` on your output.
              '';
              tools = [ "filesystem" "bash" ];
            };
            polyglot-coder = {
              mode = "subagent";
              model = "anthravity/claude-sonnet-4-5-thinking";
              prompt = ''
                You are an Expert Software Engineer specializing in Bash, Python 3 and PHP 8.3+.
                - BASH: Use 'set -euo pipefail', local variables, and prioritize readability. Always assume `shellcheck` will be run.
                - PYTHON: Prioritize type hinting and use standard libraries unless specialized ones are requested.
                - PHP: Use modern 8.3 features, strict typing, and clean architectural patterns.
                - TASK: When writing scripts that parse data, check if @web-extractor has data available first.
                - Output ONLY the code and a brief explanation of how to execute it.
              '';
              tools = [ "bash" ]; # Can run local tests to verify script syntax
            };
            secops = {
              mode = "subagent";
              model = "anthropic/claude-3-5-sonnet-latest";
              prompt = "Ethical Hacker. Perform pentesting (ZAP/Nmap), risk modelling, and gather threat intelligence. Map findings to CVEs.";
            };
          };
          skills = {
            coding-standards = ''
              ---
              name: coding-standards
              description: Mandatory formatting and commenting rules for all scripts.
              ---
              ## Requirements
              - All Python scripts MUST have a docstring with: Purpose, Dependencies, and Author (AI).
              - All Bash scripts MUST use `set -euo pipefail` and be commented per function.
              - PHP code MUST use strict types and PHPDoc headers.
            '';
          };
          plugin = [
            # "opencode-gemini-auth@latest"
            "opencode-google-antigravity-auth@latest"
            "@tarquinen/opencode-dcp@latest"
            "@mohak34/opencode-notifier@latest"
          ];
          permission = {
            edit = "ask";
            bash = {
              # Allow non-destructive git commands with wildcards
              "git status*" = "allow";
              "git log*" = "allow";
              "git diff*" = "allow";
              "git show*" = "allow";
              "git branch*" = "allow";
              "git remote*" = "allow";
              "git config*" = "allow";
              "git rev-parse*" = "allow";
              "git ls-files*" = "allow";
              "git ls-remote*" = "allow";
              "git describe*" = "allow";
              "git tag --list*" = "allow";
              "git blame*" = "allow";
              "git shortlog*" = "allow";
              "git reflog*" = "allow";
              "git add*" = "allow";

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
            };
            read = "allow";
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
          };
          mcp = {
            grafana = {
              type = "remote";
              url = "http://10.10.1.13:5133/mcp";
              enabled = true;
            };
            unifi = {
              type = "remote";
              url = "http://10.10.1.13:5134/sse";
              enabled = true;
              headers = {
                Accept = "text/event-stream";
              };
            };
            nixos = {
              enabled = true;
              type = "local";
              command = [ "${pkgs.nix}/bin/nix" "run" "github:utensils/mcp-nixos" "--" ];
            };
          };
        };
      };
    };
  };
}
