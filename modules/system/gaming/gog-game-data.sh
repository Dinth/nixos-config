set -euo pipefail

# Import game data for the native engines (DevilutionX, VCMI) from the GOG
# offline installers on the NAS. Idempotent: a game whose data is already in
# place is skipped, so this is safe to run on every login.
#
# GOG_DIR is substituted by the Nix wrapper; override it in the environment
# to import from somewhere else.

GOG_DIR="${GOG_DIR:-@gogLibrary@}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
tmp=""

# Remove the extraction scratch directory on any exit.
cleanup() {
  if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
}
trap cleanup EXIT

# Print the newest installer matching glob $2 in library subdirectory $1
# (nothing if there is none). Globbing keeps this working when GOG bumps the
# build number in the file name.
find_installer() {
  find "$GOG_DIR/$1" -maxdepth 1 -type f -name "$2" 2>/dev/null | sort -V | tail -n1
}

# Extract only the paths listed after $1 from installer $1 into a fresh
# scratch directory next to the destination (same filesystem, so the final
# move is a rename) and leave its path in $tmp.
extract() {
  local installer="$1"
  shift
  local includes=()
  local path
  for path in "$@"; do includes+=(--include "$path"); done
  mkdir -p "$DATA_HOME"
  tmp="$(mktemp -d "$DATA_HOME/.gog-import.XXXXXX")"
  innoextract --gog --silent --output-dir "$tmp" "${includes[@]}" "$installer"
}

# Diablo + Hellfire -> DevilutionX. DIABDAT.MPQ is the base game; the four
# hf*.mpq / hellfire.mpq archives enable the Hellfire expansion.
import_diablo() {
  local dest="$DATA_HOME/diasurgical/devilution"
  if [ -e "$dest/DIABDAT.MPQ" ] && [ -e "$dest/hellfire.mpq" ]; then
    echo "diablo: data already present, skipping"
    return 0
  fi
  local installer
  installer="$(find_installer "Diablo + Hellfire/windows" 'setup_diablo*.exe')"
  if [ -z "$installer" ]; then
    echo "diablo: no installer under $GOG_DIR, skipping"
    return 0
  fi
  echo "diablo: extracting $installer"
  extract "$installer" DIABDAT.MPQ hellfire/hellfire.mpq hellfire/hfmonk.mpq \
    hellfire/hfmusic.mpq hellfire/hfvoice.mpq
  mkdir -p "$dest"
  mv -f "$tmp/DIABDAT.MPQ" "$tmp"/hellfire/*.mpq "$dest/"
  cleanup
  echo "diablo: installed to $dest"
}

# Heroes of Might and Magic 3 Complete (RoE + AB + SoD) -> VCMI, which wants
# the original Data, Maps and Mp3 directories under its user data dir.
import_heroes3() {
  local dest="$DATA_HOME/vcmi"
  if [ -n "$(find "$dest/Data" -maxdepth 1 -iname 'h3bitmap.lod' 2>/dev/null)" ]; then
    echo "heroes3: data already present, skipping"
    return 0
  fi
  local installer
  installer="$(find_installer "Heroes of Might and Magic® 3 Complete/windows/@heroes3Language@" 'setup_heroes*.exe')"
  if [ -z "$installer" ]; then
    echo "heroes3: no installer under $GOG_DIR, skipping"
    return 0
  fi
  echo "heroes3: extracting $installer"
  extract "$installer" Data Maps Mp3
  mkdir -p "$dest"
  # VCMI may already have created an empty Maps/, so merge instead of rename.
  cp -a "$tmp/Data" "$tmp/Maps" "$tmp/Mp3" "$dest/"
  cleanup
  echo "heroes3: installed to $dest"
}

if [ ! -d "$GOG_DIR" ]; then
  echo "GOG library $GOG_DIR not reachable; will retry on next start"
  exit 0
fi

import_diablo
import_heroes3
