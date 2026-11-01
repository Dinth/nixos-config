let
  michal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq";
  dinth-nixos-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhWUYbCP4MBoRhT5rSes+GCx27h1fd7yEjAAmGfnN1Y";
  michal-surface-go = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgUEaVYhvpUJMCyycsqmilyZMfVHOK/EFh4nlNaC9yi";
  r230-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEHxcwQf5t5dnvgvNX7bCN0t9jmuBBG3YC6Z0fsryusW";

  # Shared by every Mac that should get these secrets. The private half is
  # written to /etc/agenix/mac-fleet.key by a Mosyle custom command (scoped
  # to michal's devices), so a new or re-imaged Mac can decrypt without a
  # rekey. Rotate: new key here + `ragenix --rekey` + update that command.
  mac-fleet = "age1spyafzuukx5cf6jkkk8h3sx06zjrhf55zgtteurtd9uhtfx3tpkqggqz4n";

  users = [michal];
  systems = [dinth-nixos-desktop michal-surface-go r230-nixos];
  macs = [mac-fleet];
in {
  "michal-password.age".publicKeys = users ++ systems;
  "chrome-enrolment.age".publicKeys = systems;
  "wifi-password.age".publicKeys = systems;
  "wifi-iot-password.age".publicKeys = users ++ systems;
  "nas-vm-creds.age".publicKeys = users ++ systems;
  "smb-haos-creds.age".publicKeys = users ++ systems;
  "opencode-gemini.age".publicKeys = users ++ systems;
  "lnxlink-mqtt.age".publicKeys = users ++ systems;
  "tailscale-auth-key.age".publicKeys = users ++ systems;
  "id-ed25519-sk-rk-1.age".publicKeys = users ++ systems ++ macs;
  "id-ed25519-sk-rk-2.age".publicKeys = users ++ systems ++ macs;
  "id-ed25519-sk-rk-3.age".publicKeys = users ++ systems ++ macs;
  "id-ed25519.age".publicKeys = users ++ systems ++ macs;
  "id-ed25519-passphrase.age".publicKeys = users ++ systems ++ macs;
  "ha-mcp-url.age".publicKeys = users ++ systems ++ macs;
  "nextcloud-mcp-auth.age".publicKeys = users ++ systems ++ macs;
  "firefly-mcp-token.age".publicKeys = users ++ systems ++ macs;
  "t212-mcp-env.age".publicKeys = users ++ systems;
  "finance-personal.age".publicKeys = users ++ systems;
  "health-personal.age".publicKeys = users ++ systems;
  "wazuh-enrolment.age".publicKeys = users ++ systems;
  "krdp-password.age".publicKeys = users ++ systems;
  "mosyle-knowledge.age".publicKeys = users ++ systems ++ macs;
  "anki-sync-username.age".publicKeys = users ++ systems;
  "anki-sync-key.age".publicKeys = users ++ systems;
  "anki-sync-paulina-username.age".publicKeys = users ++ systems;
  "anki-sync-paulina-key.age".publicKeys = users ++ systems;
}
