#!/usr/bin/env bash
# Log in to the self-hosted Anki sync server and store the account username and
# sync key (hkey) as the ragenix secrets modules/apps/anki hands to Anki.
#
# The server hands out the key on login, so this goes through Anki's own
# sync_login rather than deriving it: the derivation changes once the server
# runs with PASSWORDS_HASHED. Re-run after changing the server password, then
# rebuild.
#
# Usage: modules/apps/anki/sync-login.sh [secret-prefix] [endpoint]
#   secret-prefix: anki-sync (default, profile "User 1") or anki-sync-paulina
set -euo pipefail

prefix="${1:-anki-sync}"
endpoint="${2:-https://anki.wickhay.uk/}"
repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
host="$(hostname)"

# Build an attribute of this host's pkgs and print its store path.
build_pkg() {
  nix build --no-link --print-out-paths "$repo#nixosConfigurations.$host.pkgs.$1"
}

# Replace secrets/<name>.age with the given plaintext, encrypted to the
# recipients in secrets/secrets.nix. The old file is removed first so ragenix
# doesn't need a private key to decrypt it before "editing".
store_secret() {
  local name="$1" value="$2" tmp
  tmp="$(mktemp)"
  printf '%s' "$value" >"$tmp"
  rm -f "$repo/secrets/$name.age"
  (cd "$repo/secrets" && EDITOR="cp $tmp" ragenix -e "$name.age")
  rm -f "$tmp"
}

read -rp "Anki sync username: " username
read -rsp "Anki sync password: " password
echo

python="$(build_pkg python3)/bin/python3"
sitePackages="$(echo "$(build_pkg anki.lib)"/lib/python3*/site-packages)"

# Credentials go in on stdin, not argv or the environment. stderr is dropped:
# the backend prints a "blocked main thread" stack trace for every call.
if ! hkey="$(
  printf '%s\n%s\n' "$username" "$password" | "$python" -I -c '
import sys
sys.path.insert(0, sys.argv[1])
from anki._backend import RustBackend
from anki.sync_pb2 import SyncLoginRequest

username, password = sys.stdin.read().splitlines()[:2]
auth = RustBackend().sync_login(
    SyncLoginRequest(username=username, password=password, endpoint=sys.argv[2])
)
print(auth.hkey)
' "$sitePackages" "$endpoint" 2>/dev/null
)" || [[ -z "$hkey" ]]; then
  echo "Login to $endpoint failed (wrong username or password?)" >&2
  exit 1
fi
unset password

store_secret "$prefix-username" "$username"
store_secret "$prefix-key" "$hkey"
echo "Stored secrets/$prefix-username.age and secrets/$prefix-key.age"
