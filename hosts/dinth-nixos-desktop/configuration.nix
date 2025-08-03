{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../secrets/deployment.nix

      ../../modules/nixos/core.nix
      ../../modules/nixos/hardware.nix
      ../../modules/nixos/packages.nix
    ];

  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
