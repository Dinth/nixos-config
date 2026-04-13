{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ragenix
  ];
  age.secrets = {
    user-password = {
      file = ./michal-password.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    chrome-enrolment = {
      file = ./chrome-enrolment.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    wifi-password = {
      file = ./wifi-password.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    wifi-iot-password = {
      file = ./wifi-iot-password.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    nas-vm-creds = {
      file = ./nas-vm-creds.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    opencode-gemini = {
      file = ./opencode-gemini.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    lnxlink-mqtt = {
      file = ./lnxlink-mqtt.age;
      owner = "michal";
      group = "users";
      mode = "0644";
    };
    tailscale-auth-key = {
      file = ./tailscale-auth-key.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    id-ed25519-sk-rk-1 = {
      file = ./id-ed25519-sk-rk-1.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    id-ed25519-sk-rk-2 = {
      file = ./id-ed25519-sk-rk-2.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    id-ed25519-sk-rk-3 = {
      file = ./id-ed25519-sk-rk-3.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
    id-ed25519 = {
      file = ./id-ed25519.age;
      owner = "michal";
      group = "users";
      mode = "0400";
    };
 
  };
}
