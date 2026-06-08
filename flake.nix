{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:nixos/nixos-hardware/master"; # Hardware Specific Configurations
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
    # upstream commit; the buildPythonPackage logic still lives in
    # modules/apps/lnxlink/default.nix.
    lnxlink = {
      url = "github:bkbilly/lnxlink";
      flake = false;
    };
    # Wazuh agent (XDR/SIEM endpoint) — not in nixpkgs. Community flake
    # providing a from-source `wazuh-agent` package + a journald-aware NixOS
    # module (`services.wazuh-agent`). Pinned to nealfennimore's fork at
    # agent 4.12.0 (≤ our 4.14.5 manager, as Wazuh requires). The overlay and
    # module are applied per-host below; `wazuh.enable` (modules/services/
    # wazuh-agent) is the homelab toggle. Compiles from source on first build.
    wazuh-agent = {
      url = "github:nealfennimore/wazuh.nix/384ddd35d27a77d7ef0681efd60f46a92a43e1b4";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # with nixos-25.11's buildPythonApplication.
    valkeyOverlay = _: prev: {
      valkey = prev.valkey.overrideAttrs (_: {
        doCheck = false;
      });
    };
    llmAgentsOverlay = final: _: let
      callPkg = path: final.callPackage (llm-agents + path) {};
      wrapBuddy = callPkg "/packages/wrapBuddy/package.nix";
      versionCheckHomeHook = callPkg "/packages/versionCheckHomeHook/package.nix";
    in {
      claude-code = final.callPackage (llm-agents + "/packages/claude-code/package.nix") {inherit wrapBuddy;};
      opencode = final.callPackage (llm-agents + "/packages/opencode/package.nix") {inherit wrapBuddy versionCheckHomeHook;};
      rtk = callPkg "/packages/rtk/package.nix";
    };
    # Two GCC/Clang version compatibility fixes for Wazuh 4.12.0 on NixOS 26.05:
    #
    # 1. GCC 14+ made -Wincompatible-pointer-types a hard error; Wazuh's
    #    bundled Berkeley DB 18.1 triggers it with old-style C function pointer
    #    initializations. Suppressed via NIX_CFLAGS_COMPILE (cc-wrapper injects
    #    this into every compiler call including the libdb sub-make).
    #
    # 2. GCC 15 / Clang 21 default to C23, where `bool` and `false` are
    #    reserved keywords. libbpf-bootstrap's vmlinux.h still uses
    #    `typedef _Bool bool` and `false = 0` enum values. Two compilation
    #    paths need fixing:
    #    a. The host shared library: `add_library(modern SHARED src/modern.bpf.c)`
    #       in CMakeLists.txt compiles the BPF source with the host GCC 15
    #       compiler. Fixed by prepending -std=gnu11 to CMAKE_C_FLAGS in the
    #       line the upstream patch already adds.
    #    b. The BPF clang invocation in FindBpfObject.cmake (belt-and-suspenders;
    #       that step already passes in practice, but the flag is correct there
    #       too).
    wazuhFixOverlay = _: prev: {
      wazuh-agent = prev.wazuh-agent.overrideAttrs (old: {
        NIX_CFLAGS_COMPILE = "-Wno-incompatible-pointer-types";
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace src/external/libbpf-bootstrap/CMakeLists.txt \
              --replace-warn \
              '-Wno-error=implicit-function-declaration -Wno-error=int-conversion' \
              '-std=gnu11 -Wno-error=implicit-function-declaration -Wno-error=int-conversion'
            substituteInPlace src/external/libbpf-bootstrap/tools/cmake/FindBpfObject.cmake \
              --replace-warn "-g -O2 -target bpf" "-std=gnu11 -g -O2 -target bpf"
          '';
      });
    };
  in {
    nixosConfigurations = {
      dinth-nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          machineType = "desktop";
          inherit catppuccin home-manager lnxlink;
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
            nixpkgs.overlays = [llmAgentsOverlay valkeyOverlay wazuh-agent.overlays.wazuh wazuhFixOverlay];
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
          inherit catppuccin home-manager lnxlink;
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
            nixpkgs.overlays = [wazuh-agent.overlays.wazuh wazuhFixOverlay];
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
          inherit catppuccin home-manager lnxlink;
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
            nixpkgs.overlays = [llmAgentsOverlay valkeyOverlay wazuh-agent.overlays.wazuh wazuhFixOverlay];
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
