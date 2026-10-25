{
  lib,
  isDarwin,
  ...
}: {
  # Cross-platform: Home Manager-only modules (plus environment.systemPackages,
  # which nix-darwin also has). Imported on NixOS and macOS alike.
  imports =
    [
      ./1Password
      ./bat
      ./btop
      ./claude-code
      ./direnv
      ./eza
      ./fzf
      ./ghostty
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
      ./anki
      ./clamav
      ./google-chrome
      ./kate
      ./konsole
      ./krdc
      ./languagetool
      ./lnxlink
      ./nextcloud-client
      ./OrcaSlicer
      ./sddm
      ./steam
    ];
}
