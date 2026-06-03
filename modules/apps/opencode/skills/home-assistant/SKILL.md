---
name: home-assistant
description: >
  Homelab workflow for Home Assistant work on the HAOS install at 10.10.1.11.
  TRIGGER WHEN: creating/editing automations, scripts, scenes, helpers, templates,
  dashboards, or ESPHome configs; debugging an automation; or changing anything on
  the HA instance. Covers the local MCP-first/verify workflow — NOT the generic HA
  rules, which live in the MCP's own home-assistant-best-practices skill.
---

# Home Assistant — local workflow

This skill is the **homelab-specific** layer. It does **not** restate generic HA
best practices — those are authoritative in the `homeassistant` MCP's bundled
`home-assistant-best-practices` skill. Full detail is in the `homeassistant`
knowledge file.

## 1. Load the source of truth first
Before authoring or refactoring, read the MCP's best-practices skill via
`ha_get_skill_guide` (or the `skill://home-assistant-best-practices/SKILL.md`
resource) and the reference file it points to. It owns native-vs-template, helper
selection, automation modes, `entity_id` vs `device_id`, Zigbee patterns, safe
refactoring, dashboards, and the live deprecation list.

> That skill is written against the **official built-in HA MCP**, which is less
> capable than ours. Our `homeassistant` server is a superset — follow the skill's
> principles but reach for our richer `ha_*` toolset; don't assume a capability is
> missing just because the built-in MCP lacks it.

## 2. Work through the `homeassistant` MCP (write-capable)
- **Inspect first:** `ha_search_entities` / `ha_get_state` / `ha_config_get_*` —
  never guess at existing entities or config.
- **Create via config API:** `ha_config_set_automation` / `_script` / `_scene` /
  `_helper`, not pasted YAML.
- **Validate:** `ha_check_config`; pre-flight Jinja with `ha_eval_template`.

## 3. Verify every change — not done until the trace is clean
Apply → trigger (`ha_call_service`, e.g. `automation.trigger`) → read
`ha_get_automation_traces` / `ha_get_logs` (watch for `Error executing script`,
`Invalid data for call_service`, `TypeError`, template-variable warnings) →
confirm via `ha_get_state` → fix and re-run. Report what the trace showed.

## 4. Local non-negotiables
- Jinja templates always carry a default: `states('sensor.x') | float(0)`.
- Local-push over cloud-poll; `entity_id` over `device_id`.
- `djlint` for `{{`/`{%` files, `yamlfmt` for plain YAML.
- Reload suffices for automations/scripts/scenes/groups/themes; full restart only
  for new `configuration.yaml` integrations and platform-based sensors.
- Never hand-edit `.storage/` or `configuration.yaml` for UI-configured integrations.
- Tablet dashboards: ≥ 44×44 px touch targets, 3–4 column Sections on 11".

## 5. Escalation
No MCP access (free tier)? Draft YAML and hand to `@home-assistant-agent` to
validate/apply/verify. Need cross-host log correlation? Ask `@triage-specialist`.
