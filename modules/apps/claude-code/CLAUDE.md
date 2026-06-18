# Global Claude Code Instructions

## Network Hosts & Topology

### LAN subnets
The LAN is `10.10.0.0/16`, segmented into:

| Subnet | Purpose |
|--------|---------|
| `10.10.0.0/24` | Network equipment (router, switches, APs) |
| `10.10.1.0/24` | Servers |
| `10.10.10.0/24` | Workstations, mobile devices, DHCP pool |
| `10.10.25.0/24` | Generic IoT devices |
| `10.10.30.0/24` | CCTV cameras |

| Hostname | IP | Role | OS |
|----------|----|------|----|
| `dinth-nixos-desktop` | local | Primary workstation | NixOS |
| `michal-surface-go` | local | Mobile workstation | NixOS |
| `omv` / `r720-omv` | `10.10.1.13` | Primary server — most Docker stacks, NAS storage | OpenMediaVault (Debian-based) |
| `r230-nixos` | `10.10.1.12` | Secondary server — Docker stacks on NixOS | NixOS |
| `r230-proxmox` | `10.10.1.16` | Virtualization host — Proxmox VE (SSH `dinth@`, passphrase-protected key) | Proxmox VE |
| `homeassistant` | `10.10.1.11` | Home automation hub | Home Assistant OS (HAOS) |

### Key Facts
- Most Docker stacks run on `10.10.1.13` (`omv`); `r230-nixos` at `10.10.1.12` is a separate NixOS host that also runs containers.
- Home Assistant on `10.10.1.11` is a **native HAOS install — not a Docker container**.
- NixOS hosts: `dinth-nixos-desktop`, `michal-surface-go`, `r230-nixos`.
- Ollama (local LLM inference) runs on `10.10.1.13:11434`.

### Network equipment (`10.10.0.0/24`)

| Device | IP | Role | Managed via |
|--------|----|------|-------------|
| pfSense | `10.10.0.1` | **Router / firewall** — routing & firewall rules, NAT, DHCP, VLANs, DNS | SSH, pfSense web UI |
| Dell PowerConnect 5548P | `10.10.0.20` | **Managed switch** — wired switch ports, VLANs, PoE | SSH (`dell-switch` host, legacy algos) |
| UniFi APs | `10.10.0.0/24` | **Wi-Fi access points only** | UniFi MCP |

**Read before querying the UniFi MCP:** the UniFi controller (and its MCP) covers
**only Wi-Fi / access points** — SSIDs, WLANs, wireless clients, RF/channels, AP
adoption. It does **not** know about routing, firewall rules, NAT, or wired switch
ports.

- Routing / firewall / NAT / DHCP / VLAN-on-the-router question → **pfSense
  `10.10.0.1`** (SSH), not UniFi.
- Wired switch port / PoE / port-VLAN question → **Dell PowerConnect 5548P
  `10.10.0.20`** (SSH `dell-switch`), not UniFi.

Don't reach for the UniFi MCP for those — it returns nothing useful and wastes the session.

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

- **IP:** `10.10.1.11` — Home Assistant OS (HAOS), **native install, not Docker**
- **API:** `http://10.10.1.11:8123`
- **Config share:** HAOS `/config` is CIFS-mounted at `/mnt/haos`. Working there
  auto-loads HA mode (see `/mnt/haos/CLAUDE.md`).
- **MCP:** the `homeassistant` MCP server (project-scoped to `/mnt/haos` and
  `/mnt/haos/esphome`, URL from the ragenix `ha-mcp-url` secret) exposes `ha_*`
  tools to read, validate, and write HA config. **This is the way to inspect and
  change HA** — it is write-capable; mutations prompt for approval. It is not
  wired in `nixos-config`.

**For any HA work, delegate to the `home-assistant` subagent.** It is MCP-first and
carries the full convention set. It also loads the authoritative
`home-assistant-best-practices` skill that the MCP ships (via `ha_get_skill_guide` /
the `skill://home-assistant-best-practices/SKILL.md` resource) — that skill is the
source of truth for native-vs-template choices, helper selection, automation modes,
`entity_id` vs `device_id`, Zigbee patterns, safe refactoring, dashboards, and the
current deprecation list. Do not re-derive those rules here.

- ESPHome nodes talk to HA directly on `10.10.1.11`.
- HA metrics → Prometheus on `10.10.1.13`; logs → Promtail → Loki on `10.10.1.13`.

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
