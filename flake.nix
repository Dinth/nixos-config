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
    # lnxlink is a non-flake source input; the packaging lives beside its
    # module. Exposing it as pkgs.lnxlink keeps the input out of specialArgs
    # and lets the module consume it through a normal `package` option.
    lnxlinkOverlay = final: _: {
      lnxlink = final.callPackage ./modules/apps/lnxlink/package.nix {src = lnxlink;};
    };
    # llm-agents.nix ships plain package.nix files that expect to be called from
    # the flake's own package scope (its flake.nix builds one with lib.makeScope,
    # providing platformSource, wrapBuddy and the other ~140 packages by name).
    #
    # We can't consume llm-agents.packages.${system} directly: it goes through
    # blueprint, which evaluates the whole set eagerly, including `apm`, which
    # fails to build under our nixpkgs pin.
    #
    # We also no longer call each package.nix with a hand-written argument list.
    # That couples us to argument lists upstream never promised to keep stable,
    # and it broke twice in eight days -- once when they added a `flake` arg,
    # again when they added `platformSource`. Instead, reconstruct the same scope
    # they use, so every helper and sibling package resolves *by name* and any
    # argument they add later is satisfied automatically.
    #
    # Attribute values in Nix are lazy, so declaring all ~140 packages costs
    # nothing and `apm` is never forced -- we only pull out the three we install.
    llmAgentsOverlay = final: _: let
      inherit (final) lib;
      packageNames =
        builtins.attrNames
        (lib.filterAttrs (_: type: type == "directory")
          (builtins.readDir (llm-agents + "/packages")));
      scope = lib.makeScope final.newScope (
        self:
          {
            system = final.stdenv.hostPlatform.system;
            # Upstream reads `flake.lib.licenses.unfree` in meta only. llm-agents
            # is a non-flake source input here, so hand it nixpkgs lib, which has
            # licenses.unfree, rather than the flake's own extended lib.
            flake = {inherit lib;};
            platformSource = import (llm-agents + "/lib/platform-source.nix") {
              inherit (final) stdenv fetchurl;
            };
            allPackages = lib.genAttrs packageNames (name: self.${name});
            # Only reachable from packages we don't install (bun2nix-built ones).
            # Left as lazy throws so they never fire for claude-code/opencode/rtk
            # but give a clear message if a future arg change pulls them in.
            inputs = throw "llm-agents: `inputs` unavailable -- it is a non-flake source input here.";
            bun2nixLib = throw "llm-agents: `bun2nixLib` unavailable -- requires the upstream bun2nix input.";
          }
          // lib.genAttrs packageNames (
            name: self.callPackage (llm-agents + "/packages/${name}/package.nix") {}
          )
      );
    in {
      inherit (scope) claude-code opencode rtk;
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
            nixpkgs.overlays = [lnxlinkOverlay llmAgentsOverlay wazuhOverlay];
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
            nixpkgs.overlays = [lnxlinkOverlay llmAgentsOverlay wazuhOverlay];
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
