set -euo pipefail

# Import game data for the native engines (DevilutionX, VCMI) from the GOG
# offline installers on the NAS, plus the Heroes 3 HD Edition graphics from a
# local Steam install. Idempotent: a game whose data is already in
# place is skipped, so this is safe to run on every login.
#
# GOG_DIR is substituted by the Nix wrapper; override it in the environment
# to import from somewhere else.

GOG_DIR="${GOG_DIR:-@gogLibrary@}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STEAM_HD_DIR="${STEAM_HD_DIR:-$DATA_HOME/Steam/steamapps/common/Heroes of Might & Magic III - HD Edition}"
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
  # Hellfire's hidden Bard and Barbarian classes: DevilutionX only lists them
  # when hfbard.mpq/hfbarb.mpq (an unofficial fan pack) exist or these
  # settings are on. Seed the settings on a fresh install only; the game owns
  # diablo.ini afterwards.
  if [ ! -e "$dest/diablo.ini" ]; then
    printf '[Game]\nTest Bard=1\nTest Barbarian=1\n' >"$dest/diablo.ini"
  fi
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

# Write a VCMI mod.json to $1. $2 = name, $3 = description, $4 = modType,
# $5 = optional language (Translation submods only).
write_mod_json() {
  jq -n --arg name "$2" --arg description "$3" --arg modType "$4" --arg language "${5:-}" '
    {modType: $modType, name: $name, description: $description,
     author: "Ubisoft", version: "1.0", contact: "vcmi.eu"}
    + (if $language != "" then {language: $language} else {} end)
  ' >"$1"
}

# Heroes 3 HD Edition (Steam) -> VCMI "hd-edition" mod. Reproduces the
# launcher's HD import (launcher/modManager/hdextractor.cpp in VCMI 1.7):
# the x2/x3 texture archives become submods, the localised ones a
# translation submod per scale. Copied rather than linked so the Steam
# install can be removed afterwards.
import_hd_edition() {
  local dest="$DATA_HOME/vcmi/Mods/hd-edition"
  if [ -e "$dest/mod.json" ]; then
    echo "hd-edition: mod already present, skipping"
    return 0
  fi
  if [ ! -e "$STEAM_HD_DIR/HOMM3 2.0.exe" ]; then
    echo "hd-edition: no Steam install at $STEAM_HD_DIR, skipping"
    return 0
  fi
  echo "hd-edition: importing from $STEAM_HD_DIR"

  # The localisation directory present in this install (EN, PL, ...) and
  # the language name VCMI uses for it.
  local -A languages=([CH]=chinese [CZ]=czech [DE]=german [EN]=english
    [ES]=spanish [FR]=french [IT]=italian [PL]=polish [RU]=russian)
  local code="" candidate
  for candidate in "${!languages[@]}"; do
    if [ -d "$STEAM_HD_DIR/data/LOC/$candidate" ]; then code="$candidate"; fi
  done

  mkdir -p "$DATA_HOME"
  tmp="$(mktemp -d "$DATA_HOME/.gog-import.XXXXXX")"
  local mod="$tmp/hd-edition"
  mkdir -p "$mod/content/data/flags"
  write_mod_json "$mod/mod.json" "Heroes III HD Edition" \
    "Extracted resources from official Heroes HD to make it usable on VCMI" Graphical
  cp "$STEAM_HD_DIR/data/spriteFlagsInfo.txt" "$mod/content/data/"
  cp "$STEAM_HD_DIR"/data/flags/* "$mod/content/data/flags/"

  local scale sub
  for scale in 2 3; do
    sub="$mod/mods/x$scale"
    mkdir -p "$sub/content/data"
    write_mod_json "$sub/mod.json" "HD (x$scale)" "Resources (x$scale)" Graphical
    cp "$STEAM_HD_DIR/data/bitmap_DXT_com_x$scale.pak" \
      "$STEAM_HD_DIR/data/sprite_DXT_com_x$scale.pak" "$sub/content/data/"

    if [ -n "$code" ]; then
      sub="$mod/mods/x${scale}_loc_$code"
      mkdir -p "$sub/content/data"
      write_mod_json "$sub/mod.json" "HD Localisation (${languages[$code]}) (x$scale)" \
        "Translated Resources (x$scale)" Translation "${languages[$code]}"
      cp "$STEAM_HD_DIR/data/LOC/$code/bitmap_DXT_loc_x$scale.pak" \
        "$STEAM_HD_DIR/data/LOC/$code/sprite_DXT_loc_x$scale.pak" "$sub/content/data/"
    fi
  done

  mkdir -p "$DATA_HOME/vcmi/Mods"
  mv "$mod" "$dest"
  cleanup
  echo "hd-edition: installed to $dest"
}

import_hd_edition

if [ ! -d "$GOG_DIR" ]; then
  echo "GOG library $GOG_DIR not reachable; will retry on next start"
  exit 0
fi

import_diablo
import_heroes3
