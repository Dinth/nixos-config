{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.gaming;
in
{
  config = mkIf cfg.enable {
  };
}
