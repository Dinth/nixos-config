{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
in
{
  config = mkIf pkgs.stdenv.isDarwin {
    # Darwin-specific settings here
  };
}
