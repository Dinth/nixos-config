{ config, ... }:
{
  imports = [
    ./apps
    ./hardware
    ./services
    ./system
  ];
}
