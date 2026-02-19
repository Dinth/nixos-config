# Network Hosts & Topology

| Hostname | IP | Role | OS |
|----------|----|------|----|
| `dinth-nixos-desktop` | local | Primary workstation — runs OpenCode | NixOS |
| `michal-surface-go` | local | Mobile workstation | NixOS |
| `omv` / `r230-nixos` | `10.10.1.13` | Primary server — all Docker stacks, NAS storage | OpenMediaVault (Debian-based) |
| `homeassistant` | `10.10.1.11` | Home automation hub | Home Assistant OS (HAOS) |

Note: `omv` is the network/service name; `r230-nixos` is the NixOS hostname for
the same machine (Dell PowerEdge R230). Both refer to `10.10.1.13`.

## Key facts
- All Docker stacks run on `10.10.1.13` unless explicitly stated otherwise.
- Home Assistant on `10.10.1.11` is a **native HAOS install — not a Docker container**.
- Only `dinth-nixos-desktop` and `michal-surface-go` run NixOS — everything
  else is Debian-based or HAOS.
- Migration of some services to additional hosts is planned. Always ask which
  host a new service should target rather than assuming `10.10.1.13`.
- Ollama (local LLM inference) runs on `10.10.1.13:11434`.

## Services reachable on the network
| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | `http://10.10.1.13:8123` | Via Traefik proxy |
| MCP Gateway | `http://10.10.1.13:4888/sse` | SSE, exposes hass-mcp / docker-mcp / filesystem |
| Grafana | `http://10.10.1.13` (proxied) | Monitoring dashboards |
| Ollama | `http://10.10.1.13:11434/v1` | Local LLM inference |
| Komodo | `http://10.10.1.13` (proxied) | Stack deployment manager |
