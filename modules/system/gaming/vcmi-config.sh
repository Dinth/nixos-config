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
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/vcmi-config/enabled.json"
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

# Which of the wanted mods to switch on now, per preset: installed ones that
# this script has not enabled before. What it enabled is remembered in
# STATE_FILE, so a mod the user later switches off in the launcher stays off.
# (VCMI's own modSettings cannot tell us that: it records settings for every
# installed mod, enabled or not.)
if [ ! -s "$STATE_FILE" ]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  echo '{}' >"$STATE_FILE"
fi
# shellcheck disable=SC2016 # $installed/$done/... below are jq variables, not shell
to_enable="$(jq --argjson installed "$(installed_mods)" --slurpfile done "$STATE_FILE" '
  with_entries(.key as $preset
    | .value |= map(select(. as $m
        | ($installed | index($m)) != null
          and (($done[0][$preset] // []) | index($m)) == null)))
' "$PRESETS_FILE")"

# Create each preset if missing and append the mods chosen above.
# shellcheck disable=SC2016
patch_json "$CONFIG_DIR/modSettings.json" --tab --argjson enable "$to_enable" '
  .activePreset //= "default"
  | reduce ($enable | to_entries[]) as $e (.;
      .presets[$e.key].mods //= ["vcmi"]
      | .presets[$e.key].settings //= {}
      | .presets[$e.key].mods |= (. + ($e.value - .))
    )
'

# shellcheck disable=SC2016
patch_json "$STATE_FILE" --argjson enable "$to_enable" '
  reduce ($enable | to_entries[]) as $e (.; .[$e.key] = ((.[$e.key] // []) + $e.value))
'
