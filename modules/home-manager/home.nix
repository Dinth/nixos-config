{config, pkgs, inputs,lib, machineType, ...}:
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
      signal-desktop
    ];
  };

  catppuccin = {
#    enable = true;
    flavor = "mocha";
  };


}
