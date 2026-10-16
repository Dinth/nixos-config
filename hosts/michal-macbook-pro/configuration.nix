{
  config,
  pkgs,
  catppuccin,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../secrets/deployment.nix
  ];
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
  };

  networking.hostName = "michal-macbook-pro";

  cli.enable = true;
  agenticAi.enable = true;

  home-manager.users.${config.primaryUser.name} = {
    imports = [catppuccin.homeModules.catppuccin];
    home = {
      stateVersion = "26.05";
      username = config.primaryUser.name;
      homeDirectory = "/Users/${config.primaryUser.name}";
    };
  };

  environment.systemPackages = [pkgs.ffmpeg];

  # nix-darwin's own state version (independent of the NixOS/HM releases).
  system.stateVersion = 6;
}
