{config, pkgs, inputs,lib, ...}:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  imports = [
    ./shell.nix
    ./mc.nix
  ];
}
