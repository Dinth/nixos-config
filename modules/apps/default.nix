{
  lib,
  isDarwin,
  ...
}: {
  # Cross-platform: Home Manager-only modules (plus environment.systemPackages,
  # which nix-darwin also has). Imported on NixOS and macOS alike.
  imports =
    [
      ./bat
      ./btop
      ./claude-code
      ./direnv
      ./eza
      ./fzf
      ./git
      ./htop
      ./mc
      ./neovim
      ./opencode
      ./ssh
      ./starship
      ./weechat
      ./zoxide
      ./zsh
    ]
    # Linux-only: KDE apps, systemd units, udev/security wrappers, or apps
    # that on the Mac are better left to Mosyle/Homebrew.
    ++ lib.optionals (!isDarwin) [
      ./1Password
      ./anki
      ./clamav
      ./google-chrome
      ./kate
      ./konsole
      ./krdc
      ./lnxlink
      ./nextcloud-client
      ./OrcaSlicer
      ./sddm
      ./steam
    ];
}
