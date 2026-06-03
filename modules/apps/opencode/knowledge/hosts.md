# Network Hosts & Topology

## LAN subnets
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
| `dinth-nixos-desktop` | local | Primary workstation — runs OpenCode | NixOS |
| `michal-surface-go` | local | Mobile workstation | NixOS |
| `omv` / `r720-omv` | `10.10.1.13` | Primary server — most Docker stacks, NAS storage | OpenMediaVault (Debian-based) |
| `r230-nixos` | `10.10.1.12` | Secondary server — Docker stacks on NixOS | NixOS |
| `homeassistant` | `10.10.1.11` | Home automation hub | Home Assistant OS (HAOS) |

## Key facts
- Most Docker stacks run on `10.10.1.13` (`omv`); `r230-nixos` at `10.10.1.12`
  is a separate NixOS host that also runs containers.
- Home Assistant on `10.10.1.11` is a **native HAOS install — not a Docker container**.
- NixOS hosts: `dinth-nixos-desktop`, `michal-surface-go`, `r230-nixos`.
- Always ask which host a new service should target rather than assuming
  `10.10.1.13`.
- Ollama (local LLM inference) runs on `10.10.1.13:11434`.

## Network equipment (`10.10.0.0/24`)

| Device | IP | Role | Managed via |
|--------|----|------|-------------|
| pfSense | `10.10.0.1` | **Router / firewall** — routing & firewall rules, NAT, DHCP, VLANs, DNS | `ssh-mcp` / pfSense web UI |
| Dell PowerConnect 5548P | `10.10.0.20` | **Managed switch** — wired switch ports, VLANs, PoE | SSH (`dell-switch` host, legacy algos) |
| UniFi APs | `10.10.0.0/24` | **Wi-Fi access points only** | UniFi MCP |

**Read before querying the UniFi MCP:** the UniFi controller (and its MCP) covers
**only Wi-Fi / access points** — SSIDs, WLANs, wireless clients, RF/channels, AP
adoption. It does **not** know about routing, firewall rules, NAT, or wired switch
ports.

- Routing / firewall / NAT / DHCP / VLAN-on-the-router question → **pfSense
  `10.10.0.1`** (`ssh-mcp`), not UniFi.
- Wired switch port / PoE / port-VLAN question → **Dell PowerConnect 5548P
  `10.10.0.20`** (SSH `dell-switch`), not UniFi.

Don't reach for the UniFi MCP for those — it returns nothing useful and wastes the session.

## Services reachable on the network
| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | `http://10.10.1.13:8123` | Web UI via Traefik proxy (HAOS host is `10.10.1.11`) |
| Home Assistant MCP | `$HOMEASSISTANT_MCP_URL` (`10.10.1.11`) | The `homeassistant` MCP — `ha_*` tools; see the homeassistant knowledge file |
| MCP Gateway | `http://10.10.1.13:4888/sse` | SSE, exposes docker-mcp / filesystem |
| Grafana | `http://10.10.1.13` (proxied) | Monitoring dashboards |
| Ollama | `http://10.10.1.13:11434/v1` | Local LLM inference |
| Komodo | `http://10.10.1.13` (proxied) | Stack deployment manager |
