# Home Assistant config share

This directory is the **live Home Assistant OS `/config` share**
(`//10.10.1.11/config`, mounted at `/mnt/haos`). Everything here is HAOS's running
configuration — edits take effect on the `homeassistant` host at `10.10.1.11`.

**Operate in Home Assistant mode for all work here.** Use the `home-assistant`
skill, and for non-trivial automation/template/dashboard/ESPHome work delegate to
the `home-assistant` subagent.

- The `homeassistant` MCP (`ha_*` tools) is wired for this project and is
  **write-capable** — prefer it over hand-edited YAML. Inspect with
  `ha_get_state` / `ha_search_entities`, create via `ha_config_set_*`, validate
  with `ha_check_config`, and verify with `ha_get_automation_traces` /
  `ha_get_logs`. Mutations prompt for approval.
- Load the MCP's `home-assistant-best-practices` skill first
  (`ha_get_skill_guide`) — it is the source of truth for native-vs-template,
  helper selection, automation modes, and the current deprecation list.
- Jinja templates always carry a default (`| float(0)`); never edit `.storage/`
  by hand; reload rather than restart where possible.

> This `CLAUDE.md`, `AGENTS.md`, and the `.mcp.json` files are deployed here by the
> nixos-config Home Manager activation — don't hand-edit them; change the source in
> `modules/apps/{claude-code,opencode}/`.
