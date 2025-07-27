{ config, ... }:
{
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
  };
}
