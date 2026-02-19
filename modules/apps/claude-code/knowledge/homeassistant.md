# Home Assistant

## Host
- **IP:** `10.10.1.11`
- **OS:** Home Assistant OS (HAOS) — native install, **not a Docker container**
- **API:** `http://10.10.1.11:8123`

## MCP Access
Use the `hass-mcp` tool (via MCP gateway at `10.10.1.13:4888`) to interact
with Home Assistant. Available operations: read/write entities, automations,
scripts, helpers, and config.

**Always fetch and read the full automation or entity YAML via `hass-mcp`
before suggesting any changes.** Never guess at existing state.

## YAML Conventions
- All Jinja2 templates must have default values to prevent boot-looping:
  ```yaml
  # Good
  {{ states('sensor.temperature') | float(0) }}
  # Bad — will error if sensor is unavailable
  {{ states('sensor.temperature') | float }}
  ```
- Prioritize **local-push** integrations over cloud-poll for low latency.
- Use `djlint` formatting for any files containing `{{` or `{%` blocks.

## Debugging Automations
1. Fetch the automation via `hass-mcp` by name or `entity_id`
2. Read the full YAML — check triggers, conditions, and actions
3. Check any referenced entities/scripts/helpers via `hass-mcp`
4. If logs are needed, ask `@triage-specialist` for the error trace from Loki
5. Return a corrected YAML block — not just a description of the fix

## Integration with the Rest of the Homelab
- HA metrics can be scraped by Prometheus on `10.10.1.13`
- HA logs are shipped via Promtail → Loki on `10.10.1.13`
- ESPHome devices communicate directly with HA on `10.10.1.11`
