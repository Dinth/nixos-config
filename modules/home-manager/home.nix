{config, pkgs, inputs,lib, ...}:
let
  catppuccin_konsole = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "konsole";
    rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
    hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
  };
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  home = {
    stateVersion = "25.05";
    username = "michal";
    homeDirectory = "/home/michal";
    packages = with pkgs; [
      mqtt-explorer
      discord
      orca-slicer
      signal-desktop
      weechat
    ];
  };
  imports = [
    ./mc.nix
    ./kde.nix
    ./shell.nix
    ./mime.nix
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

}
