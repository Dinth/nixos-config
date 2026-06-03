# Home Assistant

## Host
- **IP:** `10.10.1.11`
- **OS:** Home Assistant OS (HAOS) — native install, **not a Docker container**
- **API:** `http://10.10.1.11:8123`

## MCP Access
Interact with HA through the **`homeassistant`** MCP server (wired in
`modules/apps/opencode/default.nix`; the auth-keyed URL comes from the ragenix
`ha-mcp-url` secret via `$HOMEASSISTANT_MCP_URL`). It exposes `ha_*` tools to
read, validate, and **write** HA config and to call services. You are
write-capable; enable it per-agent with `tools.homeassistant = true`.

Key tools:
- **Read:** `ha_get_overview`, `ha_get_state`, `ha_get_entity`,
  `ha_search_entities`, `ha_get_history`, `ha_config_get_automation`,
  `ha_config_list_helpers`, `ha_list_services`
- **Validate:** `ha_check_config`, `ha_eval_template`
- **Write:** `ha_config_set_automation`, `ha_config_set_script`,
  `ha_config_set_scene`, `ha_config_set_helper`, `ha_call_service`, `ha_set_entity`
- **Verify:** `ha_get_automation_traces`, `ha_get_logs`

**Always fetch and read the live state/config via the MCP before changing
anything.** Never guess at existing entities or automations.

## Source of Truth — the bundled best-practices skill
The `homeassistant` MCP ships an authoritative, versioned
**`home-assistant-best-practices`** skill. **Load it before authoring or
refactoring** — `ha_get_skill_guide`, or read the
`skill://home-assistant-best-practices/SKILL.md` resource — and follow the
reference file it points to. It is the source of truth for native-vs-template
choices, helper selection, automation modes, `entity_id` vs `device_id`, Zigbee
button patterns, safe refactoring, dashboards, and the current deprecation list
(e.g. `color_temp`→`color_temp_kelvin`, presence `entered_home` triggers removed,
add-ons renamed "Apps"). It moves with each HA release, so don't re-derive its
rules from memory.

> **Caveat:** that skill is written against the **official built-in HA MCP**, which
> is less capable than ours. Our `homeassistant` server is a superset — the same
> principles apply, but we have a richer `ha_*` toolset (full config read/write,
> traces, template eval, logs, the skill guide). Follow the skill's reasoning, but
> reach for our fuller tools; don't assume a capability is missing just because the
> doc's built-in MCP lacks it.

## Authoring rules (local non-negotiables)
- **Native over template** — prefer `numeric_state`/`state`/`time` conditions,
  `wait_for_trigger`, and built-in helpers (`min_max`, `group`, `threshold`,
  `derivative`, `utility_meter`) over Jinja. Templates skip load-time validation
  and fail silently.
- **`entity_id` over `device_id`** (ZHA buttons → `device_ieee`; Z2M
  autodiscovered device triggers are the documented exception).
- **Create through the config API** (`ha_config_set_*`), not pasted YAML — it
  validates and applies atomically. Hand back raw YAML only on explicit request
  or if the MCP is unavailable.
- **Jinja defaults always** — `{{ states('sensor.temperature') | float(0) }}` so a
  missing entity can't boot-loop HA.
- **Local-push over cloud-poll** — ZHA / Zigbee2MQTT / ESPHome / MQTT push.
- **Lint** — `djlint` for files containing `{{` or `{%`; `yamlfmt` for plain YAML.

## Verify every change
1. `ha_check_config` before and after — never leave config invalid.
2. Apply via the relevant `ha_config_set_*` tool.
3. Pre-flight non-trivial Jinja with `ha_eval_template`.
4. Trigger it (`ha_call_service`, e.g. `automation.trigger`).
5. Read `ha_get_automation_traces` / `ha_get_logs`; watch for
   `Error executing script`, `Invalid data for call_service`, `TypeError`,
   template-variable warnings.
6. Confirm the expected entity changed via `ha_get_state`.
7. Fix and re-run until the trace is clean.

## Reload vs restart
- **Reload** suffices for automations, scripts, scenes, template entities,
  groups, themes (config-API edits reload automatically).
- **Full restart** is needed for new integrations in `configuration.yaml`, core
  config changes, and platform-based `mqtt`/`min_max`/sensor platforms.

## ESPHome
- Pin platform/framework versions explicitly; `web_server` for diagnostics only;
  battery devices use `deep_sleep` + MQTT push; API keys in `secrets.yaml`.
- ESPHome nodes communicate with HA directly on `10.10.1.11`.

## Dashboards
- Tablet-heavy setup: design for touch — ≥ 44×44 px targets, 3–4 column Sections
  layouts on 11", minimise vertical scrolling, Panel view for full-screen content.
- Manage dashboards through the MCP config tools; never hand-edit `.storage/`.

## Monitoring integration
- HA metrics → Prometheus on `10.10.1.13`; logs → Promtail → Loki on `10.10.1.13`.
- Read recent logs/traces directly via `ha_get_logs` / `ha_get_automation_traces`.
  For deep cross-host correlation, ask `@triage-specialist` (owns the Grafana MCP).
