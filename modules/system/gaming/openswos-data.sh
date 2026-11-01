set -euo pipefail

# Build OpenSWOS's game data in ~/.swos/assets (where the game looks by
# default) from the season pack plus the GOG PC game on the NAS. The PC game
# adds the DOS graphics, sounds, commentary and music; the converter then takes
# the teams from it (96/97), so with OPENSWOS_TEAMS=season the season pack's
# team files are put back on top. Idempotent: skips when nothing it was built
# from has changed, and exits quietly when the NAS is unreachable (the game
# then falls back to the Amiga-only data in the store).
#
# The @...@ values are substituted by the Nix wrapper.

GOG_DIR="${GOG_DIR:-@gogLibrary@}"
SEASON_PACK="@seasonPack@"
SEASON_ASSETS="@seasonAssets@"
RES_DIR="@resDir@"
OPENSWOS_TEAMS="${OPENSWOS_TEAMS:-@teams@}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PC_DIR="$DATA_HOME/openswos/pc"
ASSETS="$HOME/.swos/assets"
STAMP="$ASSETS/.nix-stamp"
tmp=""

# Remove the scratch directory on any exit.
cleanup() {
  if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT

# Unpack the GOG installer $1 into PC_DIR (once; the installer is the
# DOSBox-wrapped DOS game, which is what swosdata --dos reads).
unpack_pc_game() {
  if [ -e "$PC_DIR/.installer" ] && [ "$(cat "$PC_DIR/.installer")" = "$1" ]; then
    return 0
  fi
  echo "openswos: unpacking $1"
  mkdir -p "$(dirname "$PC_DIR")"
  tmp="$(mktemp -d "$PC_DIR.XXXXXX")"
  innoextract --gog --silent --exclude-temp --output-dir "$tmp" "$1"
  printf '%s\n' "$1" >"$tmp/.installer"
  rm -rf "$PC_DIR"
  mv "$tmp" "$PC_DIR"
  tmp=""
}

# Convert the season pack and the PC game into a fresh assets tree and swap
# it in for the old one.
build_assets() {
  mkdir -p "$HOME/.swos"
  tmp="$(mktemp -d "$HOME/.swos/.assets.XXXXXX")"
  swosdata --adf "$SEASON_PACK" --dos "$PC_DIR" --out "$tmp" --res "$RES_DIR"
  if [ "$OPENSWOS_TEAMS" = season ]; then
    echo "openswos: teams from the season pack"
    local rel
    swosdata --list-parts "$SEASON_ASSETS" | awk -F '\t' '$1 == "teams" { print $3 }' |
      while IFS= read -r rel; do
        mkdir -p "$tmp/$(dirname "$rel")"
        cp -f "$SEASON_ASSETS/$rel" "$tmp/$rel"
      done
  fi
  chmod -R u+w "$tmp"
  printf '%s\n' "$1" >"$tmp/.nix-stamp"
  rm -rf "$ASSETS"
  mv "$tmp" "$ASSETS"
  tmp=""
}

installer="$(find "$GOG_DIR/Sensible World of Soccer 96 97/windows" -maxdepth 1 -type f \
  -name 'setup_sensible_world_of_soccer*.exe' 2>/dev/null | sort -V | tail -n1 || true)"
if [ -z "$installer" ]; then
  echo "openswos: no GOG installer under $GOG_DIR, skipping"
  exit 0
fi

stamp="$RES_DIR|$SEASON_PACK|$installer|$OPENSWOS_TEAMS"
if [ -e "$STAMP" ] && [ "$(cat "$STAMP")" = "$stamp" ]; then
  echo "openswos: data up to date, skipping"
  exit 0
fi

unpack_pc_game "$installer"
build_assets "$stamp"
echo "openswos: data built in $ASSETS"
