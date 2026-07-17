{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Hardware Specific Configurations. Its own nixpkgs input is only used by
    # upstream's CI/examples, so follow ours — otherwise the lock pins a
    # second, unused nixpkgs snapshot that every fresh clone has to fetch.
    nixos-hardware = {
      url = "github:nixos/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix/release-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager/";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Prebuilt nix-index database so `command-not-found` works without
    # having to run `nix-index` locally (~10 min) every release.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # lnxlink — Linux companion app for Home Assistant. Tracked as a
    # source input so `nix flake update lnxlink` brings the latest
    # upstream commit; packaged by modules/apps/lnxlink/package.nix and
    # exposed as pkgs.lnxlink via lnxlinkOverlay below.
    lnxlink = {
      url = "github:bkbilly/lnxlink";
      flake = false;
    };
    # Wazuh agent (XDR/SIEM endpoint) — not in nixpkgs. Community flake
    # providing a from-source `wazuh-agent` package + a journald-aware NixOS
    # module (`services.wazuh-agent`). Pinned to nealfennimore's fork at
    # agent 4.12.0 (≤ our 4.14.5 manager, as Wazuh requires).
    #
    # Deliberately NOT following our nixpkgs: the agent is a huge C/C++ build
    # that upstream only tests against its own lock. Following rolling
    # unstable meant recompiling on every nixpkgs bump and chasing toolchain
    # regressions (four fix commits for GCC 14/15/Clang 21, since deleted).
    # `wazuh-nixpkgs` pins the exact rev from the fork's own flake.lock
    # (Oct 2024, GCC 13), where 4.12.0 compiles clean with no patches — the
    # agent builds once and its store path never changes until these pins are
    # bumped (keep them in step: fork commit + rev from its flake.lock).
    # Runtime is self-contained under /var/ossec, so the older glibc in its
    # closure is irrelevant. See wazuhOverlay below.
    wazuh-nixpkgs.url = "github:nixos/nixpkgs/1997e4aa514312c1af7e2bda7fad1644e778ff26";
    wazuh-agent = {
      url = "github:nealfennimore/wazuh.nix/384ddd35d27a77d7ef0681efd60f46a92a43e1b4";
      inputs.nixpkgs.follows = "wazuh-nixpkgs";
    };

    #     nix-darwin = {
    #       url = "github:nix-darwin/nix-darwin/master";
    #       inputs.nixpkgs.follows = "nixpkgs";
    #     };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    plasma-manager,
    catppuccin,
    agenix,
    nixos-hardware,
    nixvirt,
    llm-agents,
    nix-index-database,
    lnxlink,
    wazuh-agent,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    # Overlay to use llm-agents.nix packages for claude-code, opencode, and rtk.
    # Call each package directly from the flake source rather than via
    # llm-agents.packages.${system}, which uses blueprint and eagerly evaluates
    # the entire package set — including the broken `apm` package that fails
    # to build under our nixpkgs pin.
    valkeyOverlay = _: prev: {
      valkey = prev.valkey.overrideAttrs (_: {
        doCheck = false;
      });
    };
    # Keep the 32-bit (pkgsi686Linux) closure from compiling a full numerical
    # stack (numpy → lapack → openblas) from source. The 32-bit PipeWire pulled
    # in for games' ALSA audio drags it in transitively, and Hydra does not
    # populate the i686 cache for it, so it builds locally — openblas' test
    # suite alone is ~6h. The stack enters only through *test-only* inputs of
    # two widely-used Python build deps; cutting both removes it from every path
    # (pipewire → libcamera/ffado/roc-toolkit/… all funnel through these):
    #
    #  1. pybind11 lists numpy directly in nativeCheckInputs. On i686 its tests
    #     are already not built (upstream gates buildTests on host/build CPU
    #     bit-depth matching, which differ for i686-on-x86_64), yet numpy is
    #     still pulled because doCheck defaults true.
    #  2. pyfakefs lists pandas (→ numpy) in nativeCheckInputs, and pyfakefs sits
    #     in the closure of setuptools/distutils — i.e. nearly every i686 Python
    #     build — so it is the single cut point for all the scons/meson-built
    #     PipeWire features.
    #
    # Disabling doCheck on these loses nothing on i686 (no i686-relevant tests)
    # and is scoped to i686 so the cached x86_64 builds stay byte-identical.
    i686LeanOverlay = _: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isi686 {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (_: pyprev: {
              pybind11 = pyprev.pybind11.overridePythonAttrs (_: {doCheck = false;});
              pyfakefs = pyprev.pyfakefs.overridePythonAttrs (_: {doCheck = false;});
            })
          ];
      };
    # lnxlink is a non-flake source input; the packaging lives beside its
    # module. Exposing it as pkgs.lnxlink keeps the input out of specialArgs
    # and lets the module consume it through a normal `package` option.
    lnxlinkOverlay = final: _: {
      lnxlink = final.callPackage ./modules/apps/lnxlink/package.nix {src = lnxlink;};
    };
    llmAgentsOverlay = final: _: let
      callPkg = path: final.callPackage (llm-agents + path) {};
      wrapBuddy = callPkg "/packages/wrapBuddy/package.nix";
      versionCheckHomeHook = callPkg "/packages/versionCheckHomeHook/package.nix";
    in {
      # llm-agents' claude-code/package.nix (>= 2026-07-12) takes a `flake`
      # arg, used only for `flake.lib.licenses.unfree` in meta. llm-agents is a
      # non-flake source here, so hand it a shim exposing nixpkgs lib (which
      # has licenses.unfree) rather than the flake's own extended lib.
      claude-code = final.callPackage (llm-agents + "/packages/claude-code/package.nix") {
        inherit wrapBuddy;
        flake = {inherit (final) lib;};
      };
      opencode = final.callPackage (llm-agents + "/packages/opencode/package.nix") {inherit wrapBuddy versionCheckHomeHook;};
      rtk = callPkg "/packages/rtk/package.nix";
    };
    # The fork's NixOS module reads its agent from pkgs.wazuh-agent
    # (mkPackageOption). Supply the fork's own prebuilt output — evaluated
    # against the fork's locked nixpkgs, not ours — so nixpkgs bumps never
    # rebuild or break it (see the wazuh-agent input comment).
    wazuhOverlay = _: _: {
      wazuh-agent = wazuh-agent.packages.${system}.wazuh-agent;
    };
  in {
    nixosConfigurations = {
      dinth-nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          machineType = "desktop";
          inherit catppuccin home-manager;
        };
        modules = [
          ./libs
          ./modules
          ./hosts/dinth-nixos-desktop/configuration.nix
          agenix.nixosModules.default
          catppuccin.nixosModules.catppuccin
          nix-index-database.nixosModules.nix-index
          nixvirt.nixosModules.default
          wazuh-agent.nixosModules.wazuh-agent
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [lnxlinkOverlay llmAgentsOverlay valkeyOverlay wazuhOverlay i686LeanOverlay];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              sharedModules = [plasma-manager.homeModules.plasma-manager agenix.homeManagerModules.default];
            };
          }
        ];
      };
      r230-nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          machineType = "server";
          inherit catppuccin home-manager;
        };
        modules = [
          ./libs
          ./modules
          ./hosts/r230-nixos/configuration.nix
          agenix.nixosModules.default
          catppuccin.nixosModules.catppuccin
          nix-index-database.nixosModules.nix-index
          wazuh-agent.nixosModules.wazuh-agent
          # nixvirt is not imported here — r230 runs no VMs and the
          # virtualisation module gates NixVirt-only options behind
          # hasNixVirt so eval succeeds without it.
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [lnxlinkOverlay wazuhOverlay];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              sharedModules = [agenix.homeManagerModules.default];
            };
          }
        ];
      };
      michal-surface-go = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          machineType = "tablet";
          inherit catppuccin home-manager;
        };
        modules = [
          ./libs
          ./modules
          ./hosts/michal-surface-go/configuration.nix
          agenix.nixosModules.default
          catppuccin.nixosModules.catppuccin
          nix-index-database.nixosModules.nix-index
          nixos-hardware.nixosModules.microsoft-surface-go
          wazuh-agent.nixosModules.wazuh-agent
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [lnxlinkOverlay llmAgentsOverlay valkeyOverlay wazuhOverlay i686LeanOverlay];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              sharedModules = [plasma-manager.homeModules.plasma-manager agenix.homeManagerModules.default];
            };
          }
        ];
      };
    };

    # `nix fmt` — formats every .nix file in the tree with alejandra.
    formatter.${system} = pkgs.alejandra;

    # `nix flake check` — host evals + repo-wide lints.
    checks.${system} = {
      # Verify each host configuration evaluates and builds.
      dinth-nixos-desktop = self.nixosConfigurations.dinth-nixos-desktop.config.system.build.toplevel;
      michal-surface-go = self.nixosConfigurations.michal-surface-go.config.system.build.toplevel;
      r230-nixos = self.nixosConfigurations.r230-nixos.config.system.build.toplevel;

      # Format check — fails if any .nix file would be reformatted.
      format = pkgs.runCommand "check-alejandra" {nativeBuildInputs = [pkgs.alejandra];} ''
        cd ${self}
        alejandra --check .
        touch $out
      '';

      # Dead-code lint — unused let bindings, inherits, etc.
      # `--no-lambda-pattern-names` so module-arg patterns like
      # `{ config, lib, pkgs, ... }` don't flag every unused arg.
      deadnix = pkgs.runCommand "check-deadnix" {nativeBuildInputs = [pkgs.deadnix];} ''
        cd ${self}
        deadnix --no-lambda-pattern-names --fail .
        touch $out
      '';

      # Anti-pattern lint — `with pkgs;` overuse, redundant rec, etc.
      # Lint exceptions live in ./statix.toml at the repo root.
      statix = pkgs.runCommand "check-statix" {nativeBuildInputs = [pkgs.statix];} ''
        cp ${./statix.toml} statix.toml
        statix check ${self}
        touch $out
      '';
    };

    # Doesnt work
    #       darwinConfigurations = {
    #         michal-macbook-pro = nix-darwin.lib.darwinSystem {
    #           system = "aarch64-darwin";
    #           specialArgs = { machineType = "laptop"; };
    #           modules = [
    #             ./libs
    #             ./modules
    #             ./hosts/michal-macbook-pro/configuration.nix
    #             agenix.nixosModules.default
    # #            catppuccin.nixosModules.catppuccin
    #             home-manager.darwinModules.home-manager
    #             {
    #               home-manager.useGlobalPkgs = true;
    #               home-manager.useUserPackages = true;
    #               home-manager.verbose = true;
    #               home-manager.users.michal = {
    #                 imports = [
    #                   catppuccin.homeModules.catppuccin
    #                 ];
    #               };
    #             }
    #           ];
    #         };
    #       };
  };
}
