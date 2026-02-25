# Global Claude Code Instructions

## Network Hosts & Topology

| Hostname | IP | Role | OS |
|----------|----|------|----|
| `dinth-nixos-desktop` | local | Primary workstation | NixOS |
| `michal-surface-go` | local | Mobile workstation | NixOS |
| `omv` / `r230-nixos` | `10.10.1.13` | Primary server — all Docker stacks, NAS storage | OpenMediaVault (Debian-based) |
| `homeassistant` | `10.10.1.11` | Home automation hub | Home Assistant OS (HAOS) |

Note: `omv` is the network/service name; `r230-nixos` is the NixOS hostname for the same machine (Dell PowerEdge R230).

### Key Facts
- All Docker stacks run on `10.10.1.13` unless explicitly stated otherwise.
- Home Assistant on `10.10.1.11` is a **native HAOS install — not a Docker container**.
- Only `dinth-nixos-desktop` and `michal-surface-go` run NixOS.
- Ollama (local LLM inference) runs on `10.10.1.13:11434`.

### Services

| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | `http://10.10.1.13:8123` | Via Traefik proxy |
| Grafana | `http://10.10.1.13` (proxied) | Monitoring dashboards |
| Ollama | `http://10.10.1.13:11434/v1` | Local LLM inference |
| Komodo | `http://10.10.1.13` (proxied) | Stack deployment manager |

---

## NixOS Configuration

### Repo Location
The NixOS config lives at `/home/michal/Documents/nixos-config`. Always read the relevant existing module before modifying anything.

### Architecture
- **Flakes** — `flake.nix` is the entry point
- **System + Home Manager are mixed** — a single module may contain both `environment.systemPackages` and `home-manager.users.${user}.programs.*`
- **Secrets** — managed with **ragenix**. Never use sops or plain agenix.

### Folder Structure
```
flake.nix
hosts/                        # Per-host entry points + hardware config
  dinth-nixos-desktop/
  michal-surface-go/
  r230-nixos/
libs/                         # Reusable declarations, helper functions
modules/
  apps/                       # Single-app configs
  hardware/                   # Hardware-specific configuration
  services/                   # System services
  system/                     # Large subsystems spanning multiple apps
secrets/                      # ragenix-encrypted secrets
```

### Module Conventions
Always use `mkOption` with an `enable` option:
```nix
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption;
  cfg = config.<moduleName>;
in {
  options.<moduleName> = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config = mkIf cfg.enable {
    # implementation
  };
}
```

### Key Constraints
- Run `nix-instantiate --parse` to check syntax before presenting output
- Verify packages with `nix search nixpkgs#<package>`
- On build failures, use `nix-instantiate --show-trace`
- Never introduce a new secrets mechanism — use ragenix

---

## Docker Infrastructure

### Source of Truth
Stack definitions live in GitHub:
```
https://github.com/Dinth/komodo_library/<stack_name>/docker-compose.yml
```

### Deployment Workflow
```
edit → commit → push to GitHub → manually trigger deploy in Komodo
```

**Never edit files on the server directly.** Always output full compose files for the user to commit and push.

### Persistent Data
Data lives on `10.10.1.13` under `/opt/docker/`:
```
/opt/docker/<stack>/<container_name>/
                    ├── config/
                    ├── data/
                    └── logs/
```

### Environment Variables
All vars managed in **Komodo** — never hardcode secrets.
Global vars: `${TZ}`, `${DOCKER_PUID}`, `${DOCKER_PGID}`, `${DOCKER_SOCKET_GID}`

### Compose Conventions
1. **x-versions block** for image pinning:
   ```yaml
   x-versions:
     service-name-version: &service-name-version image/name:1.2.3
   ```
2. **x-logging reusable block** — every service gets `logging: *default-logging`
3. **Security hardening** on every service:
   ```yaml
   ipc: private
   restart: unless-stopped
   security_opt: ["no-new-privileges:true"]
   cap_drop: [ALL]
   user: "${DOCKER_PUID}:${DOCKER_PGID}"
   ```
4. **Memory limits** — always set `mem_limit`
5. **WUD labels**: `wud.watch: "true"`
6. **Volumes** — bind mounts to `/opt/docker/`, include `/etc/localtime:/etc/localtime:ro`
7. **Traefik** — join external `traefik` network, use labels, never publish ports directly

### Workflow Checklist
**Creating a new stack:**
1. Ask for stack name if not obvious
2. Fetch existing stacks from GitHub to check for conflicts
3. Apply all conventions
4. Ask: Traefik-exposed or internal-only?
5. List `${ENV_VARS}` needed in Komodo
6. Output the full file

**Editing an existing stack:**
1. Fetch current compose from GitHub first
2. Preserve existing conventions
3. Output the full updated file

---

## Home Assistant

- **IP:** `10.10.1.11`
- **OS:** Home Assistant OS (HAOS) — native install, **not Docker**
- **API:** `http://10.10.1.11:8123`

### YAML Conventions
Always use default values in Jinja2 templates:
```yaml
# Good
{{ states('sensor.temperature') | float(0) }}
# Bad — will error if unavailable
{{ states('sensor.temperature') | float }}
```

### Debugging Automations
1. Fetch the automation by name or `entity_id`
2. Read the full YAML — triggers, conditions, actions
3. Check referenced entities/scripts/helpers
4. Return a corrected YAML block — not just a description

### Integration
- Metrics scraped by Prometheus on `10.10.1.13`
- Logs shipped via Promtail → Loki on `10.10.1.13`
- ESPHome devices communicate directly with HA

---

## Coding Standards

### Python
- All scripts MUST have a docstring with: Purpose, Dependencies, and Author (AI)

### Bash
- All scripts MUST use `set -euo pipefail`
- Comment each function

### PHP
- MUST use strict types (`declare(strict_types=1);`)
- MUST include PHPDoc headers
