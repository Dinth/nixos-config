{ config, lib, pkgs, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
}
