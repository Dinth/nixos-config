set -euo pipefail

# Apply the declarative parts of the VCMI configuration on top of the files
# VCMI itself owns and rewrites (settings.json, modSettings.json). Run from
# home-manager activation, so it re-applies on every rebuild.
#
# Usage: vcmi-config <mod-id>...   (the Nix-managed mods under Mods/)

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vcmi"
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

# Launcher: no update check for VCMI itself, no automatic refresh of the mod
# repository (the mods are pinned in Nix), and skip the first-run wizard —
# game data is imported by gog-game-data.
patch_json "$CONFIG_DIR/settings.json" --tab '
  .launcher.updateOnStartup = false
  | .launcher.autoCheckRepositories = false
  | .launcher.setupCompleted = true
'

# Enable each Nix-managed mod in the active preset the first time VCMI sees
# it. A mod that already has a `settings` entry is known to VCMI, so leave it
# alone: that keeps a mod the user switched off in the launcher switched off.
mods_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
# shellcheck disable=SC2016 # $p/$m/$mods below are jq variables, not shell
patch_json "$CONFIG_DIR/modSettings.json" --tab --argjson mods "$mods_json" '
  .activePreset //= "default"
  | .activePreset as $p
  | .presets[$p].mods //= ["vcmi"]
  | .presets[$p].settings //= {}
  | .presets[$p] |= (
      .settings as $known
      | .mods as $active
      | .mods += [
          $mods[] as $m
          | select($known[$m] == null and ($active | index($m)) == null)
          | $m
        ]
    )
'
