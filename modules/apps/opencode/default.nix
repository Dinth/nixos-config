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

  # AGENTS.md marker dropped onto the HAOS /config CIFS share (outside $HOME,
  # so home.file can't manage it). Dropped at both /mnt/haos and the common
  # /mnt/haos/esphome subproject so opencode picks it up regardless of which it
  # is launched from. Guarded by `[ -d ]` (triggers the autofs mount) and
  # best-effort so a rebuild never fails when HAOS is unreachable.
  mergeHaosMarkerScript = pkgs.writeShellScript "write-opencode-haos-marker.sh" ''
    set -euo pipefail
    for d in /mnt/haos /mnt/haos/esphome; do
      if [ -d "$d" ]; then
        ${lib.getExe' pkgs.coreutils "cp"} -f ${./haos/AGENTS.md} "$d/AGENTS.md" || true
      fi
    done
  '';
in {
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
        prettier
        mcp-nixos
        djlint
        ruff
        nix-output-monitor
        rtk # Rust Token Killer - reduces LLM token consumption
      ];
      # Knowledge files — split by topic, loaded per-agent to avoid wasting context
      home.file.".config/opencode/knowledge/hosts.md".source = ./knowledge/hosts.md;
      home.file.".config/opencode/knowledge/docker.md".source = ./knowledge/docker.md;
      home.file.".config/opencode/knowledge/homeassistant.md".source = ./knowledge/homeassistant.md;
      home.file.".config/opencode/knowledge/nixos.md".source = ./knowledge/nixos.md;
      home.file.".config/opencode/skills" = {
        source = ./skills;
        recursive = true;
      };
      # Export the Home Assistant MCP URL (private auth key) from the ragenix
      # secret so opencode's `homeassistant` MCP can resolve `{env:...}` at
      # launch. Declared here (not only in the claude-code module) so opencode
      # doesn't silently depend on claude-code being enabled. Home Manager
      # merges this with any other initContent fragment; a double export is
      # harmless and idempotent.
      programs.zsh.initContent = lib.mkAfter ''
        if [ -r "${config.age.secrets.ha-mcp-url.path}" ]; then
          export HOMEASSISTANT_MCP_URL="$(< "${config.age.secrets.ha-mcp-url.path}")"
        fi
      '';
      # Drop the HA marker (AGENTS.md) onto the /mnt/haos CIFS share so working
      # there auto-loads HA mode. The homeassistant MCP is already global.
      home.activation.opencodeHaosMarker = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${mergeHaosMarkerScript}
      '';
      home.sessionVariables = {
        OPENCODE_LOG_LEVEL = "debug"; # Force debug logging at env level
        #        OPENCODE_METRICS_ENABLED = "true";
        #        OPENCODE_METRICS_ENDPOINT = "http://10.10.1.13:9090/metrics";  # Prometheus - to add
      };
      programs.opencode = {
        enable = true;
        tui.theme = "catppuccin";
        settings = {
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
              options = {
                baseURL = "http://10.10.1.13:11434/v1";
              };
              #               timeout = 240000;  # 3 minutes - local models can be slower
              #               retryAttempts = 2;  # Fewer retries for local server
              #               retryDelay = 500;
              #               retryExponentialBase = 1.5;
              #               maxRetryDelay = 5000;
              models = {
                "gpt-oss:20b" = {
                  name = "GPT-OSS 20B";
                  tools = true;
                };
                "mistral-nemo:latest" = {
                  name = "Mistral Nemo";
                  tools = true;
                };
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
            # "opencode-gemini-auth@latest"
            "opencode-google-antigravity-auth@latest"
            "@tarquinen/opencode-dcp@latest"
            "@mohak34/opencode-notifier@latest"
            "rtk-for-opencode@latest" # Rust Token Killer - reduces token consumption by 60-90%
          ];
          # Bash patterns generated from libs/agent-permissions.nix.
          # Each base command produces two glob entries — the literal
          # spelling and the `rtk <cmd>` mirror — so RTK's PreToolUse
          # rewrite still hits the right rule.
          permission = let
            bashFromList = decision: cmds:
              lib.listToAttrs (lib.concatMap (cmd: [
                  {
                    name = "${cmd}*";
                    value = decision;
                  }
                  {
                    name = "rtk ${cmd}*";
                    value = decision;
                  }
                ])
                cmds);
          in {
            bash =
              bashFromList "ask" config.agentPermissions.askBash
              // bashFromList "allow" config.agentPermissions.readOnlyBash;
            # Auto-allow the read-only HA skill-guide MCP tool (the
            # home-assistant agent loads it on every run). opencode names
            # MCP tools `<server>_<tool>`.
            "homeassistant_ha_get_skill_guide" = "allow";
            edit = "ask";
            read = "allow";
            context_info = "allow";
            list = "allow";
            glob = "allow";
            grep = "allow";
            webfetch = "allow";
            websearch = "allow";
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
              extensions = [".php"];
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
              extensions = [".py"];
            };
            xml = {
              command = [(lib.getExe pkgs.lemminx)];
              extensions = [".xml"];
            };
          };
          formatter = {
            nixfmt = {
              command = [
                (lib.getExe pkgs.nixfmt)
                "$FILE"
              ];
              extensions = [".nix"];
            };
            jsonc = {
              command = [
                (lib.getExe pkgs.prettier)
                "--parser"
                "json"
                "$FILE"
              ];
              extensions = [".json"];
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
              extensions = [".py"];
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
            # Scope: Wi-Fi / access points ONLY. Routing/firewall lives on pfSense
            # (10.10.0.1), wired switching on the Dell PowerConnect 5548P
            # (10.10.0.20) — both via SSH, not UniFi. See knowledge/hosts.md.
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
              command = [(lib.getExe pkgs.mcp-nixos)];
              timeout = 15000;
            };
            # Home Assistant MCP — the same server Claude Code uses. The URL holds
            # a private auth key, so it comes from the ragenix `ha-mcp-url` secret
            # via the $HOMEASSISTANT_MCP_URL env var (exported in zsh below);
            # opencode resolves `{env:...}` at launch. Per-agent access is gated
            # by `tools.homeassistant = true` in agents.nix.
            homeassistant = {
              type = "remote";
              url = "{env:HOMEASSISTANT_MCP_URL}";
              enabled = true;
              timeout = 20000;
            };
          };
        };
      };
    };
  };
}
