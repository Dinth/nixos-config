# Agent definitions for opencode.
# Imported by opencode.nix as: agent = import ./agents.nix;
{
  # ─────────────────────────────────────────────────────────────
  # PAID AGENTS
  # ─────────────────────────────────────────────────────────────
  manager = {
    mode = "primary";
    model = "google/gemini-2.5-pro";
    # model = "opencode/claude-sonnet-4-5";
    # High-level overview only — enough to delegate correctly,
    # no deep Docker/HA detail needed here.
    knowledge = [ "hosts" ];
    prompt = ''
      You are the Technical Project Manager. Analyze user intent and delegate to specialists. For complex web research, use @procurement. For NixOS configuration, use @nixos-engineer.
    '';
    temperature = 0.3;
    topP = 0.9;
    topK = 40;
    maxTokens = 4096;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    delegation = {
      maxDelegationDepth = 3;
      delegationTimeout = 300000;
      allowedSubagents = [
        "nixos-engineer"
        "polyglot-coder"
        "procurement"
        "triage-specialist"
        "infra-manager"
        "home-assistant-agent"
        "docs-specialist"
        "secops"
      ];
    };
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
    # No homelab knowledge needed — this agent does external research only
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
    delegation = {
      maxDelegationDepth = 2;
      allowedSubagents = [
        "web-extractor"
      ];
    };
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
    # No homelab knowledge needed — pure web parsing specialist
    prompt = ''
      You are a Parsing & Reverse-Engineering Specialist.
            STATIC SITES: Extract CSS selectors, XPath patterns, pagination logic.

            DYNAMIC/SPA SITES:
            - Inspect <script> tags for embedded JSON (window.__INITIAL_STATE__, etc.)
            - Look for fetch()/XHR patterns in bundled JS to discover hidden REST/GraphQL APIs
            - Check for /api/, /_next/data/, /wp-json/, /graphql endpoints
            - Identify auth requirements (cookies, tokens, headers)

            OUTPUT FORMAT (always structured):
            - site_type: static | spa | hybrid
            - recommended_approach: dom_scraping | json_api | rss_exists
            - endpoints: [{url, method, headers_needed, sample_response_schema}]
            - dom_selectors: [{purpose, css_selector, example_value}]
            - pagination: {type, pattern}
            - caveats: [rate_limits, cloudflare, paywalls, etc.]

            Convert raw HTML into clean JSON/Markdown.
    '';
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
    # Needs host topology and Docker stack locations; not HA YAML conventions
    knowledge = [
      "hosts"
      "docker"
    ];
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
    # Needs full picture to document changes accurately
    knowledge = [
      "hosts"
      "docker"
      "homeassistant"
    ];
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
    # Needs host topology and NixOS config structure; not Docker conventions or HA detail
    knowledge = [
      "hosts"
      "nixos"
    ];
    prompt = ''
      You are a NixOS Specialist.
      - Your goal is to maintain the system closure in /etc/nixos.
      - When a task requires a custom script (Bash/Python/PHP), DELEGATE the script generation to @polyglot-coder.
      - Once @polyglot-coder provides the script, wrap it in a Nix expression (like `pkgs.writeShellScriptBin` or `virtualisation.oci-containers`).
      - Always run `nix-instantiate --parse` or `nixfmt-rfc-style` on your output.
      ERROR HANDLING:
       - If a Nix build fails, run `nix-instantiate --show-trace` or `nom build` for detailed errors
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
    delegation = {
      maxDelegationDepth = 2;
      allowedSubagents = [
        "polyglot-coder"
        "docs-specialist"
      ];
      mustDelegateFor = [
        "bash-script"
        "python-script"
        "php-script"
      ];
    };
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
    # Needs HA specifics and host context; not Docker compose conventions
    knowledge = [
      "hosts"
      "homeassistant"
    ];
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
    # Full picture — this agent manages the entire homelab
    knowledge = [
      "hosts"
      "docker"
      "homeassistant"
    ];
    prompt = ''
      You are the Network Custodian.
      - READ first: Always consult your loaded knowledge files to locate devices
        and understand the infrastructure before taking any action.
      - SSH ACCESS: Use the `ssh-mcp` tool for Debian/pfSense.
      - CONTEXT: You know that only Desktop and Surface Go are NixOS;
        omv (10.10.1.13) is Debian-based; HA (10.10.1.11) is HAOS.
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
    # Minimal context — host IPs only in case scripts need to reference
    # the homelab (e.g. a backup script targeting 10.10.1.13)
    knowledge = [ "hosts" ];
    prompt = ''
      You are an Expert Software Engineer specializing in Bash, Python 3 and PHP 8.3+.
      - BASH: Use 'set -euo pipefail', local variables, and prioritize readability. Always assume `shellcheck` will be run.
      - PYTHON: Prioritize type hinting and use standard libraries unless specialized ones are requested.
      - PHP: Use modern 8.3 features, strict typing, and clean architectural patterns.
      - WEB PARSING: When a task requires parsing, scraping, or understanding a website's structure,
        ALWAYS delegate to @web-extractor first. Use its structured output as your implementation spec.
        Prefer JSON API endpoints over HTML parsing when web-extractor finds them.
      - Output ONLY the code and a brief explanation of how to execute it.
    '';
    skills = [ "coding-standards" ];
    temperature = 0.1;
    topP = 0.1;
    topK = 10;
    maxTokens = 8192;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    delegation = {
      maxDelegationDepth = 2;
      allowedSubagents = [
        "web-extractor"
      ];
    };
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
    # No homelab knowledge — operates against external targets only
    prompt = ''
      You are an Ethical Hacker and Security Specialist.
      - RECON & DISCOVERY: Before running active tools (ZAP/Nmap), delegate to @web-extractor
        to passively map endpoints, discover hidden APIs, inspect JS bundles for auth flows,
        and identify the attack surface. Use its findings to focus active scans.
      - ACTIVE TESTING: Run ZAP/Nmap/nikto against the endpoints web-extractor identified.
      - OUTPUT: Perform risk modelling, map findings to CVEs, and produce a structured report
        with severity ratings and remediation steps.
    '';
    temperature = 0.4;
    topP = 0.9;
    topK = 40;
    maxTokens = 8192;
    frequencyPenalty = 0.2;
    presencePenalty = 0.15;
    delegation = {
      maxDelegationDepth = 2;
      allowedSubagents = [
        "web-extractor"
      ];
    };
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

  # ─────────────────────────────────────────────────────────────
  # FREE AGENTS
  # All models via opencode Zen provider (zero cost).
  # NOTE: These free tiers are temporary promotions — if a model
  # disappears, swap in big-pickle as a stopgap or promote to a
  # paid agent. Model IDs confirmed against opencode.ai/zen/v1/models
  # on 2026-02-14.
  #
  # free-manager  → orchestrates free workflow (kimi-k2.5-free)
  # free-coder    → code generation / scripts (kimi-k2.5-free)
  # free-nixos    → NixOS config drafting (minimax-m2.5-free)
  # free-iot      → Home Assistant / ESPHome YAML (minimax-m2.5-free)
  # free-docs     → documentation, manual updates (glm-4.7-free)
  #
  # big-pickle (opencode/big-pickle) is intentionally NOT set as
  # primary on any agent — it is available as a manual /model switch
  # fallback due to reliability and quality regressions observed in
  # early 2026. It has 200k context so it remains useful for large
  # read-only analysis tasks if invoked directly.
  # ─────────────────────────────────────────────────────────────

  free-manager = {
    # /agent free-manager
    # Primary entry point for zero-cost sessions.
    # Invoke with: /agent free-manager
    # Mirrors the paid `manager` role but delegates only to free subagents.
    # If a task genuinely needs paid capabilities it will say so explicitly
    # rather than silently degrading.
    mode = "primary";
    model = "opencode/kimi-k2.5-free";
    # kimi-k2.5 has 256k context and strong tool-call reliability —
    # the best available free model for orchestration.
    knowledge = [ "hosts" ];
    prompt = ''
      You are the Free-Tier Technical Project Manager.
      Route every task using ONLY the free subagents listed below.
      Do NOT delegate to any paid agent under any circumstances.

      DELEGATION MAP:
      - Code / scripts (Bash, Python, PHP) → @free-polyglot-coder
      - NixOS config, modules, expressions → @free-nixos-engineer
      - Home Assistant / ESPHome YAML       → @free-home-assistant-agent
      - Documentation, manual updates       → @free-docs-specialist

      ESCALATION RULE:
      If a task requires live tool execution (SSH, filesystem writes,
      Grafana queries, nixos-rebuild), state clearly:
      "This task requires a paid agent with tool access. Switch to
      /agent manager to proceed." Do not attempt it yourself.

      Keep responses concise — free models have lower throughput.
    '';
    temperature = 0.3;
    topP = 0.9;
    topK = 40;
    maxTokens = 4096;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    delegation = {
      maxDelegationDepth = 3;
      delegationTimeout = 300000;
      allowedSubagents = [
        "free-nixos-engineer"
        "free-polyglot-coder"
        "free-home-assistant-agent"
        "free-docs-specialist"
      ];
    };
    caching = {
      enabled = true;
      ttl = 600;
      cacheSystemPrompt = true;
      cacheKnowledge = false;
    };
  };

  free-polyglot-coder = {
    # Mirrors polyglot-coder. Generates Bash/Python/PHP code without
    # executing it — output is ready for review or hand-off to
    # nixos-engineer / infra-manager for deployment.
    mode = "subagent";
    model = "opencode/kimi-k2.5-free";
    # kimi-k2.5-free: 256k context, strong structured output and
    # tool-call JSON reliability — best free option for code tasks.
    knowledge = [ "hosts" ];
    prompt = ''
      You are a free-tier Software Engineer specialising in Bash, Python 3 and PHP 8.3+.
      - BASH: Use 'set -euo pipefail', local variables, prioritise readability.
        Always write as if `shellcheck` will be run on output.
      - PYTHON: Use type hints. Prefer stdlib unless a specialised library is requested.
      - PHP: Use strict typing and modern 8.3 features.
      - OUTPUT: Code only, plus a brief usage note. No markdown fences around Nix.
      - LIMITATIONS: You do not execute code. If the task requires running a command,
        validating output, or filesystem access, say so and suggest escalating to
        @polyglot-coder (paid) via the manager.
    '';
    skills = [ "coding-standards" ];
    temperature = 0.1;
    topP = 0.1;
    topK = 10;
    maxTokens = 8192;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    # No bash/filesystem tools — free-coder is generation-only.
    # Tool execution is gated behind paid agents intentionally.
    caching = {
      enabled = true;
      ttl = 1800;
      cacheSystemPrompt = true;
      cacheKnowledge = false;
      cacheSkills = true;
    };
  };

  free-nixos-engineer = {
    # Mirrors nixos-engineer for drafting and review tasks.
    # Does NOT run nix-instantiate or nixos-rebuild — output should
    # be validated by the paid nixos-engineer before applying.
    mode = "subagent";
    model = "opencode/minimax-m2.5-free";
    # minimax-m2.5-free: built for multi-step agentic tool chains,
    # 80.2% SWE-Bench Verified, strong at structured code generation.
    knowledge = [
      "hosts"
      "nixos"
    ];
    prompt = ''
      You are a free-tier NixOS Specialist.
      - Draft Nix modules, expressions, and home-manager configs.
      - Wrap scripts in pkgs.writeShellScriptBin or similar derivations.
      - Follow RFC-style formatting (nixfmt-rfc-style conventions).
      - If a script body is needed, delegate to @free-polyglot-coder first,
        then wrap the result in the appropriate Nix expression.
      - IMPORTANT: You do not have access to a Nix evaluator.
        Always add a comment <!-- validate with: nix-instantiate --parse -->
        so the operator knows to check before applying.
      - On attribute errors or package availability questions, note that
        the paid @nixos-engineer can run `nix search` to confirm.
    '';
    temperature = 0.2;
    topP = 0.85;
    topK = 25;
    maxTokens = 8192;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    caching = {
      enabled = true;
      ttl = 900;
      cacheSystemPrompt = true;
      cacheKnowledge = true;
    };
  };

  free-home-assistant-agent = {
    # Mirrors home-assistant-agent for YAML drafting.
    # No HA MCP tool — output is YAML for manual review/paste,
    # not applied directly to the HA instance.
    mode = "subagent";
    model = "opencode/minimax-m2.5-free";
    # minimax-m2.5-free: strong on structured YAML generation and
    # multi-step reasoning needed for complex HA automations.
    knowledge = [
      "hosts"
      "homeassistant"
    ];
    prompt = ''
      You are a free-tier IoT Specialist.
      - Write Home Assistant YAML (automations, scripts, templates, input helpers).
      - Write ESPHome device configs.
      - Prioritise local-push integrations over cloud-poll.
      - JINJA2: Always include default values in templates, e.g.:
          states('sensor.temp') | float(0)
        to prevent boot-looping HA on missing entities.
      - Format: valid YAML, indented 2 spaces, ready to paste into HA.
      - LIMITATIONS: You cannot apply configs or check HA logs.
        If a running automation is broken and you need error traces,
        escalate to @triage-specialist (paid) via the manager.
    '';
    temperature = 0.3;
    topP = 0.88;
    topK = 30;
    maxTokens = 4096;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    caching = {
      enabled = true;
      ttl = 600;
      cacheSystemPrompt = true;
      cacheKnowledge = false;
    };
  };

  free-docs-specialist = {
    # Mirrors docs-specialist. Uses glm-4.7-free which is already
    # proven in this role. Pure text generation — no filesystem tool
    # needed since output is returned to the user for manual save,
    # keeping this agent completely free and tool-call-risk-free.
    mode = "subagent";
    model = "opencode/glm-4.7-free";
    knowledge = [
      "hosts"
      "docker"
      "homeassistant"
    ];
    prompt = ''
      You are a free-tier Librarian.
      - Draft additions and updates for `~/Documents/system_manual.md`.
      - Format: Markdown with Mermaid diagrams where topology changes.
      - Log format: [Date] [Agent] [Change Summary] [Impacted Systems]
      - OUTPUT: Return the drafted Markdown text only. The operator will
        paste or save it manually — you do not write to the filesystem.
    '';
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
    };
  };
}
