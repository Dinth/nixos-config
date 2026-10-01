set -euo pipefail

# Apply the declarative parts of the VCMI configuration on top of the files
# VCMI itself owns and rewrites (settings.json, modSettings.json). Run from
# home-manager activation and after the game-data import, so it re-applies
# on every rebuild and login.
#
# Usage: vcmi-config <presets.json>
#   presets.json maps a VCMI mod preset name to the mod ids it should enable:
#   {"default": ["hota", ...], "tears-of-ashan": [...]}

PRESETS_FILE="$1"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vcmi"
MODS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vcmi/Mods"
mkdir -p "$CONFIG_DIR"

# Rewrite JSON file $1 through jq (remaining arguments), starting from `{}`
# when it does not exist yet. Written via a temp file so a failed jq run
# never truncates the original.
patch_json() {
  local file="$1"
  shift
  local tmp
  tmp="$(mktemp "$file.XXXXXX")"
  if [ ! -s "$file" ]; then echo '{}' >"$file"; fi
  if jq "$@" "$file" >"$tmp"; then
    mv -f "$tmp" "$file"
  else
    rm -f "$tmp"
    echo "vcmi-config: could not patch $file, leaving it untouched" >&2
  fi
}

# Print the ids of the mods actually present under Mods/ as a JSON array.
# Mods that are not installed (e.g. hd-edition before its import) must not
# be enabled.
installed_mods() {
  local dir
  for dir in "$MODS_DIR"/*/; do
    if [ -e "${dir}mod.json" ]; then basename "$dir"; fi
  done | jq -R . | jq -s .
}

# Launcher: no update check for VCMI itself, no automatic refresh of the mod
# repository (the mods are pinned in Nix), and skip the first-run wizard —
# game data is imported by gog-game-data.
patch_json "$CONFIG_DIR/settings.json" --tab '
  .launcher.updateOnStartup = false
  | .launcher.autoCheckRepositories = false
  | .launcher.setupCompleted = true
'

# Create each preset if missing, then enable each of its installed mods the
# first time VCMI sees it. A mod that already has a `settings` entry in the
# preset is known to VCMI, so leave it alone: that keeps a mod the user
# switched off in the launcher switched off.
# shellcheck disable=SC2016 # $e/$m/... below are jq variables, not shell
patch_json "$CONFIG_DIR/modSettings.json" --tab \
  --slurpfile wanted "$PRESETS_FILE" --argjson installed "$(installed_mods)" '
  .activePreset //= "default"
  | reduce ($wanted[0] | to_entries[]) as $e (.;
      .presets[$e.key].mods //= ["vcmi"]
      | .presets[$e.key].settings //= {}
      | .presets[$e.key] |= (
          .settings as $known
          | .mods as $active
          | .mods += [
              $e.value[] as $m
              | select(($installed | index($m)) != null
                  and $known[$m] == null
                  and ($active | index($m)) == null)
              | $m
            ]
        )
    )
'
