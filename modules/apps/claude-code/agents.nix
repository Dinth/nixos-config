# Agent definitions for claude-code.
# Imported by claude-code.nix as: agent = import ./agents.nix;
{
  manager = {
    mode = "primary";
    model = "claude/claude-3-opus-20240229";
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
      ];
    };
    caching = {
      enabled = true;
      ttl = 600;
      cacheSystemPrompt = true;
      cacheKnowledge = false;
    };
  };
  procurement = {
    mode = "subagent";
    model = "claude/claude-3-sonnet-20240229";
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
  };
  web-extractor = {
    mode = "subagent";
    model = "claude/claude-3-haiku-20240307";
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
    temperature = 0.1;
    topP = 0.85;
    topK = 20;
    maxTokens = 4096;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    caching = {
      enabled = true;
      ttl = 900;
      cacheSystemPrompt = true;
      cacheKnowledge = false;
    };
  };
  nixos-engineer = {
    mode = "subagent";
    model = "claude/claude-3-opus-20240229";
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
      - If a Nix build fails, run `nix-output-monitor` or `nix-instantiate --show-trace` for detailed errors
      - Check syntax with `nix-instantiate --parse` before committing changes
      - On attribute errors, verify package availability with `nix search`
    '';
    temperature = 0.2;
    topP = 0.85;
    topK = 25;
    maxTokens = 8192;
    frequencyPenalty = 0.0;
    presencePenalty = 0.0;
    delegation = {
      maxDelegationDepth = 2;
      allowedSubagents = [
        "polyglot-coder"
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
  };
  polyglot-coder = {
    mode = "subagent";
    model = "claude/claude-3-opus-20240229";
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
  };
}
