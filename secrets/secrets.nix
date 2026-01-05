let
  michal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq";
  dinth-nixos-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhWUYbCP4MBoRhT5rSes+GCx27h1fd7yEjAAmGfnN1Y";
  michal-surface-go = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgUEaVYhvpUJMCyycsqmilyZMfVHOK/EFh4nlNaC9yi";
  r230-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEHxcwQf5t5dnvgvNX7bCN0t9jmuBBG3YC6Z0fsryusW";

  users = [ michal ];
  systems = [ dinth-nixos-desktop michal-surface-go r230-nixos ];
in
{
  "michal-password.age".publicKeys = users ++ systems;
  "chrome-enrolment.age".publicKeys = systems;
  "wifi-password.age".publicKeys = systems;
  "wifi-iot-password.age".publicKeys = users ++ systems;
  "nas-vm-creds.age".publicKeys = users ++ systems;
  "opencode-gemini.age".publicKeys = users ++ systems;
}
