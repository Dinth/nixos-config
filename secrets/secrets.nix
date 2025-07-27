let
  michal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq";
  dinth-nixos-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhWUYbCP4MBoRhT5rSes+GCx27h1fd7yEjAAmGfnN1Y";

  users = [ michal ];
  systems = [ dinth-nixos-desktop ];
in
{
  "michal-password.age".publicKeys = users ++ systems;
  "chrome-enrolment.age".publicKeys = systems;
  "wifi-password.age".publicKeys = systems;
  "wifi-iot-password.age".publicKeys = users ++ systems;
  "api-key.age".publicKeys = users ++ systems;
}
