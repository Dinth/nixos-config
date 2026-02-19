# Docker Infrastructure — Conventions & Stack Management

## Source of Truth

Stack definitions live in GitHub — this is the **only** source of truth.
```
https://github.com/Dinth/komodo_library/<stack_name>/docker-compose.yml
```
The repo is **public**. Each stack is a subfolder containing `docker-compose.yml`
and any supporting files.

### Deployment workflow
Stacks are deployed via **Komodo** (self-hosted, on `10.10.1.13`):
```
edit → commit → push to GitHub → manually trigger deploy in Komodo
```
Komodo also manages all environment variables per stack.

### Reading a stack before editing
Always fetch the current compose from GitHub before touching anything:
```
https://raw.githubusercontent.com/Dinth/komodo_library/main/<stack_name>/docker-compose.yml
```
Use `web_fetch` — no auth needed, repo is public.

**Never suggest editing files on the server directly.**
Always output the full updated compose file for the user to commit and push.

---

## Persistent Data Folder Structure

Data (volumes, configs, logs) lives on `10.10.1.13` under `/opt/docker/`,
separate from stack definitions.

Convention (not always consistent, aim for this):
```
/opt/docker/<stack>/<container_or_stack_name>_<description>/
                    ├── config/
                    ├── data/
                    └── logs/
```
Use `filesystem` MCP to inspect `/opt/docker/<stack>/` for runtime state.

---

## Environment Variables & Secrets

All vars managed in **Komodo** — never hardcode secrets in compose files.
Always use `${VAR_NAME}` placeholders.

Global vars (available to all stacks):
- `${TZ}` — timezone
- `${DOCKER_PUID}` / `${DOCKER_PGID}` — user/group for container processes
- `${DOCKER_SOCKET_GID}` — GID of the docker socket group

When writing a new stack, always list which vars need to be added in Komodo.

---

## Compose File Conventions

**Always match these exactly** when writing or editing any compose file.

### 1. x-versions block — image pinning
```yaml
x-versions:
  service-name-version: &service-name-version image/name:1.2.3
```
Reference with `image: *service-name-version`. Pin to specific version tags.
Only use `latest` if the image genuinely does not publish versioned tags.

### 2. x-logging reusable block
```yaml
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```
Every service gets `logging: *default-logging`.

### 3. Security hardening — every service
```yaml
ipc: private
restart: unless-stopped
security_opt: ["no-new-privileges:true"]
cap_drop: [ALL]
user: "${DOCKER_PUID}:${DOCKER_PGID}"
```
Only add `cap_add` if the service explicitly requires it — name the reason.

### 4. Memory limits — always set `mem_limit`
- Small utilities / sidecars: `64M`–`128M`
- App servers: `256M`–`512M`
- Databases / heavy services: `512M`–`2G`

### 5. WUD update-watcher labels
```yaml
labels:
  wud.watch: "true"
```

### 6. Volumes
- Bind mounts into `/opt/docker/<stack>/...` for all persistent data
- Always include `/etc/localtime:/etc/localtime:ro`
- No named Docker volumes unless explicitly asked

### 7. Traefik — externally exposed services
Join the external `traefik` network and use labels. Never publish ports
directly for Traefik-proxied services.

```yaml
networks:
  traefik:
    external: true
  <stack-internal>:
    name: <stack-internal>
    driver: bridge
```
```yaml
# On the service:
labels:
  wud.watch: "true"
  traefik.enable: "true"
  traefik.http.routers.<name>.rule: "Host(`<subdomain>.yourdomain.com`)"
  traefik.http.routers.<name>.entrypoints: "websecure"
  traefik.http.routers.<name>.tls.certresolver: "letsencrypt"
  traefik.http.services.<name>.loadbalancer.server.port: "<port>"
```
Internal-only services join only their stack-internal network — no Traefik
labels, no published ports.

---

## Stacks Inventory

| Stack | GitHub | Notes |
|-------|--------|-------|
| `traefik` | `komodo_library/traefik` | Reverse proxy, external network `traefik` |
| `monitoring` | `komodo_library/monitoring` | Grafana, Prometheus, Promtail, Loki, InfluxDB |
| `mcp-gateway` | `komodo_library/mcp-gateway` | MCP SSE gateway on port `4888` |
| `komodo` | `komodo_library/komodo` | Deployment manager |

### Databases
Migrating from shared Postgres/MariaDB to **per-stack databases**.
- Always create a dedicated DB container in the same compose file
- Prefer Postgres; use MariaDB only if the app requires it
- Do not reference a shared instance unless explicitly told to

### Monitoring stack
- Grafana — dashboards
- Prometheus — metrics scraping
- Promtail + Loki — log shipping and aggregation
- InfluxDB — time-series (used alongside Prometheus by some services)
- Prometheus scrape configs live in `/opt/docker/monitoring/`

---

## Workflow Checklist

### Creating a new stack
1. Ask for the stack name if not obvious
2. `web_fetch` `https://github.com/Dinth/komodo_library` to check if anything
   related already exists
3. Apply all conventions above
4. Ask: Traefik-exposed or internal-only?
5. List `${ENV_VARS}` needed in Komodo
6. Output the file — user will commit, push, and deploy

### Editing an existing stack
1. `web_fetch` the current compose from GitHub first
2. Preserve all existing conventions — do not reformat
3. Output the full updated file

### Diagnosing a broken container
1. `docker-mcp` → container state and logs
2. `web_fetch` → compose from GitHub
3. `filesystem` MCP → `/opt/docker/<stack>/` for runtime state
4. Cross-reference all three before diagnosing
