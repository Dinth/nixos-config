{
  config,
  pkgs,
  catppuccin,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # Not ../../secrets/deployment.nix: that declares every host's secrets,
    # including Linux-only ones the Mac can't (and shouldn't) decrypt.
    ./secrets.nix
  ];
  primaryUser = {
    name = "michal";
    fullName = "Michal Gawronski-Kot";
    email = "michal@gawronskikot.com";
    publicKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnJL7HYauYQWLSdKDZwGJBj/OWu+rBZEcaxS/Dn/Wtq"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHw58iDAXminEmYKnzUjRzMhpR7rvULZZUZ0izMdiuhSAAAABHNzaDo="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIK+KGs2KSEQaHkzK+awc4QXMKu6kMn10F7cZ4raPcQJKAAAABHNzaDo="
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMOPDiAQbAD53X2neUh/vbIv7pRx2+qkZ7Ti9PH+CJ1yAAAABHNzaDo="
    ];
  };

  networking.hostName = "michal-macbook-pro";

  cli.enable = true;
  # Fonts, mpv, GUI-aware bits of mc (macOS clipboard). The Linux desktop
  # stack in graphical.nix is skipped on Darwin.
  graphical.enable = true;
  agenticAi.enable = true;
  _1password.enable = true; # CLI; 1Password.app itself is installed normally
  yubikey.enable = true;
  weechat.enable = true;
  # Games come as Homebrew casks (Steam, Heroic, OpenTTD, VCMI, DevilutionX);
  # they install once homebrew.enable is turned on.
  gaming.enable = true;
  # Tailnet only away from home: down on CracoviaPany, up everywhere else.
  tailscale = {
    enable = true;
    homeSsid = "CracoviaPany";
  };
  # ssh.enable defaults to true: Remote Login with the same hardening as Linux.

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
