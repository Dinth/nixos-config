{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib) mkOption;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{

}
