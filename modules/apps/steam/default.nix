{ config, lib,...}:
let
  inherit (lib) mkIf;
  cfg = config.gaming;
in
{
  cfg = mkIf cfg.enable {
  };
}
