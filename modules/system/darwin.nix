{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
{
  config = mkIf pkgs.stdenv.isDarwin {
    # Darwin-specific settings here
  };
}
