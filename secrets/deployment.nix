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
    cloudflare-mdm = {
      file = ./cloudflare-mdm.age;
      owner = "michal";
      group = "users";
      mode = "0644";
    };
  };
}
