{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.graphical;
  primaryUsername = config.primaryUser.name;
in
{

}
