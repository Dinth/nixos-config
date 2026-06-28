# Home Assistant config share

`/mnt/haos` is the live HAOS `/config` share (`//10.10.1.11/config`). Everything
here is Home Assistant's running configuration — edits take effect on `10.10.1.11`.
**Operate in Home Assistant mode for all work here, inline.**

- Inside `/mnt/haos` you already have everything `@home-assistant-agent` does:
  the write-capable `homeassistant` MCP is wired for this project and the
  `home-assistant` skill loads here. Load the skill and use the `ha_*` tools
  directly — **do not spawn `@home-assistant-agent` from inside the share**; it
  only starts cold and re-derives context you already hold. Reserve it for
  genuinely heavy, isolated multi-step builds.
- The `homeassistant` MCP (`ha_*` tools) is available and **write-capable** —
  prefer it over hand-pasted YAML. Inspect with `ha_get_state` /
  `ha_search_entities`, create via `ha_config_set_*`, validate with
  `ha_check_config`, verify with `ha_get_automation_traces` / `ha_get_logs`.
- Load the MCP's `home-assistant-best-practices` skill first
  (`ha_get_skill_guide`) — the source of truth for native-vs-template, helpers,
  automation modes, and deprecations.
- Jinja templates always carry a default (`| float(0)`); never edit `.storage/`
  by hand; reload rather than restart where possible.

> This file is deployed here by nixos-config Home Manager activation — don't
> hand-edit it; change the source in `modules/apps/opencode/haos/AGENTS.md`.
