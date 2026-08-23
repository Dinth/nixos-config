#!/usr/bin/env bash
#
# Refresh pin.json to whatever NoMachine currently ships.
#
# NoMachine deletes a build's tarball the moment the next one is released, and
# the retired URL then 302s to their homepage -- so fetchurl silently hashes an
# HTML page and the rebuild dies on a hash mismatch. There is no archive to pin
# against and no version the vendor keeps around, so the pin has to move with
# them. This script does the whole move: scrape the current build off the
# stable download page, prefetch both tarballs, rewrite pin.json.
#
# Usage: modules/apps/nomachine-client/update.sh   (then rebuild)
# Deps:  curl, nix
set -euo pipefail

# Stable, id-addressed download page for the Linux packages. Unlike the tarball
# URLs, this one does not rot -- it always lists the current build.
readonly DOWNLOAD_PAGE='https://download.nomachine.com/download/?id=43&platform=linux'
PIN_FILE="$(dirname "$(readlink -f "$0")")/pin.json"
readonly PIN_FILE

# Print "<version> <build>" for the newest Linux tarball advertised on the page.
current_release() {
  curl -sSL "$DOWNLOAD_PAGE" \
    | grep -Eio 'nomachine-personal-edition_[0-9.]+_[0-9]+_x86_64\.tar\.gz' \
    | head -1 \
    | sed -E 's/^nomachine-personal-edition_([0-9.]+)_([0-9]+)_x86_64\.tar\.gz$/\1 \2/'
}

# Print the SRI hash of one architecture's tarball for the given version/build.
prefetch_hash() {
  local version="$1" build="$2" arch="$3"
  local url="https://download.nomachine.com/download/${version%.*}/Linux/nomachine-personal-edition_${version}_${build}_${arch}.tar.gz"
  nix hash convert --hash-algo sha256 --to sri \
    "$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1)"
}

main() {
  read -r version build < <(current_release)
  if [[ -z ${version:-} || -z ${build:-} ]]; then
    echo "could not find a tarball on $DOWNLOAD_PAGE -- did the page change?" >&2
    exit 1
  fi
  echo "NoMachine currently ships ${version}_${build}; prefetching..." >&2

  local x86_64_hash i686_hash
  x86_64_hash="$(prefetch_hash "$version" "$build" x86_64)"
  i686_hash="$(prefetch_hash "$version" "$build" i686)"

  cat > "$PIN_FILE" <<JSON
{
  "version": "$version",
  "build": "$build",
  "hashes": {
    "x86_64-linux": "$x86_64_hash",
    "i686-linux": "$i686_hash"
  }
}
JSON
  echo "wrote $PIN_FILE" >&2
}

main "$@"
