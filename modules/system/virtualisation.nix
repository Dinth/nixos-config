{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.virtualisation;
  primaryUsername = config.primaryUser.name;
in
{

}
