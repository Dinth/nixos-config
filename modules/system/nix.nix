{
  lib,
  pkgs,
  isDarwin,
  ...
}: let
  # Settings shared by both Nix implementations: upstream Nix on NixOS
  # (nix.settings) and Determinate Nix on macOS (determinateNix.customSettings,
  # rendered to /etc/nix/nix.custom.conf, which Determinate's nix.conf includes).
  sharedSettings = {
    # Rolling-latest workflow pulls large closures every rebuild; the default
    # 64 MiB download buffer overflows and logs "download buffer is full".
    # 256 MiB keeps the substituter fed without stalling on decompression.
    download-buffer-size = 268435456;
  };
  extraSubstituters = ["https://nix-community.cachix.org"];
  # Public key for nix-community.cachix.org. Without it, Nix silently
  # refuses every path that cache signs and falls back to cache.nixos.org
  # or a local rebuild — so the substituter line was dead weight until this
  # was added. cache.nixos.org's own key is a built-in default.
  extraTrustedPublicKeys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
in
  lib.mkMerge [
    {
      nixpkgs = {
        config = {
          allowUnfree = true;
          # heroic and signal-desktop pin pnpm 10.29.2 to match their lockfiles and
          # use it only as a build-time tool to fetch node deps (sandboxed, never
          # shipped at runtime). A recent nixpkgs bump flagged that pnpm version as
          # insecure, which blocks evaluation; permitting it is the upstream-advised
          # fix. Revisit when those packages bump their pinned pnpm.
          permittedInsecurePackages = [
            "pnpm-10.29.2"
          ];
        };
      };

      environment.systemPackages = [pkgs.nix-diff];

      # Command-not-found that actually works: shell hook into the
      # nix-index database. The nix-index-database flake input ships a
      # prebuilt db so we don't have to run `nix-index` locally.
      programs.nix-index.enable = true;
    }

    (lib.optionalAttrs (!isDarwin) {
      nix.settings =
        sharedSettings
        // {
          experimental-features = ["nix-command" "flakes"];
          trusted-users = ["root" "@wheel"];
          substituters = ["https://cache.nixos.org"] ++ extraSubstituters;
          trusted-public-keys = extraTrustedPublicKeys;
        };
      nix.optimise.automatic = true;
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";
      # The NixOS module adds the flake-aware clean timer and NH_FLAKE wiring.
      programs.nh.enable = true;
      # Shadows NixOS's built-in channel-based programs.command-not-found.
      programs.command-not-found.enable = false;
    })

    # Determinate Nix owns the daemon on macOS: its nix-darwin module forces
    # `nix.enable = false`, so every nix.* option here would be an error.
    # Flakes and nix-command are on by default, and determinate-nixd runs its
    # own automatic GC, so there's no nix.gc/nix.optimise equivalent to set.
    (lib.optionalAttrs isDarwin {
      determinateNix.customSettings =
        sharedSettings
        // {
          # @admin is macOS's equivalent of @wheel.
          trusted-users = ["root" "@admin"];
          # extra-* appends, so Determinate's default caches stay in front.
          extra-substituters = extraSubstituters;
          extra-trusted-public-keys = extraTrustedPublicKeys;
        };
      # No programs.nh module in nix-darwin; `nh darwin switch` just needs
      # the binary (point it at the flake with NH_FLAKE or an argument).
      environment.systemPackages = [pkgs.nh];
    })
  ]
