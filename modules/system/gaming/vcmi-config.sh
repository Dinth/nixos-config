set -euo pipefail

# Apply the declarative parts of the VCMI configuration on top of the files
# VCMI itself owns and rewrites (settings.json, modSettings.json). Run from
# home-manager activation and after the game-data import, so it re-applies
# on every rebuild and login.
#
# Usage: vcmi-config <presets.json>
#   presets.json maps a VCMI mod preset name to the mod ids it should enable
#   and, optionally, submods to switch on or off (lower-case ids, as VCMI
#   stores them):
#   {"default": {"mods": ["hota", ...]},
#    "other": {"mods": [...], "submods": {"hota": {"mainmenu": false}}}}

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

# What to apply now, per preset: wanted mods that are installed and that
# this script has not enabled before, and wanted submod switches (of
# installed mods) it has not set before. What it applied is remembered in
# STATE_FILE, so anything the user later changes in the launcher sticks.
# (VCMI's own modSettings cannot tell us that: it records settings for every
# installed mod, enabled or not.)
if [ ! -s "$STATE_FILE" ]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  echo '{}' >"$STATE_FILE"
fi
# shellcheck disable=SC2016 # $installed/$applied/... below are jq variables, not shell
todo="$(jq --argjson installed "$(installed_mods)" --slurpfile applied "$STATE_FILE" '
  with_entries(.key as $preset
    | ($applied[0][$preset] // {}) as $was
    | .value |= {
        mods: [
          (.mods // [])[] as $m
          | select(($installed | index($m)) != null
              and (($was.mods // []) | index($m)) == null)
          | $m
        ],
        submods: [
          ((.submods // {}) | to_entries[]) as $mod
          | select(($installed | index($mod.key)) != null)
          | ($mod.value | to_entries[]) as $sub
          | "\($mod.key)/\($sub.key)" as $id
          | select((($was.submods // []) | index($id)) == null)
          | {id: $id, mod: $mod.key, sub: $sub.key, on: $sub.value}
        ]
      })
' "$PRESETS_FILE")"

# Create each preset if missing, append its mods and set its submod switches.
# shellcheck disable=SC2016
patch_json "$CONFIG_DIR/modSettings.json" --tab --argjson todo "$todo" '
  .activePreset //= "default"
  | reduce ($todo | to_entries[]) as $e (.;
      .presets[$e.key].mods //= ["vcmi"]
      | .presets[$e.key].settings //= {}
      | .presets[$e.key].mods |= (. + ($e.value.mods - .))
      | reduce $e.value.submods[] as $s (.;
          .presets[$e.key].settings[$s.mod][$s.sub] = $s.on)
    )
'

# shellcheck disable=SC2016
patch_json "$STATE_FILE" --argjson todo "$todo" '
  reduce ($todo | to_entries[]) as $e (.;
    .[$e.key].mods = ((.[$e.key].mods // []) + $e.value.mods)
    | .[$e.key].submods = ((.[$e.key].submods // []) + [$e.value.submods[].id]))
'
