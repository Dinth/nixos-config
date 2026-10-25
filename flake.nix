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
    # Game sources not in nixpkgs, tracked as source inputs so
    # `nix flake update` (nh os switch -u) brings new releases; packaged in
    # modules/system/gaming and exposed via gamesOverlay below.
    # `latest` is the tag upstream moves to each new release.
    opentyrian2000-engaged = {
      url = "github:wlfn1116/OpenTyrian2000-Engaged/latest";
      flake = false;
    };
    # VCMI mods follow each repo's vcmi-1.7 branch (the branch the launcher's
    # mod repository tracks for VCMI 1.7.x). Input name = vcmi-mod-<mod id>.
    vcmi-mod-vcmi-extras = {
      url = "github:vcmi-mods/vcmi-extras/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-hota = {
      url = "github:vcmi-mods/horn-of-the-abyss/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-wake-of-gods = {
      url = "github:vcmi-mods/wake-of-gods/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-tides-of-war = {
      url = "github:vcmi-mods/tides-of-war/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-new-pavilion = {
      url = "github:vcmi-mods/new-pavilion/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-tears-of-ashan = {
      url = "github:vcmi-mods/tears-of-ashan/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-market-of-time = {
      url = "github:vcmi-mods/market-of-time/vcmi-1.7";
      flake = false;
    };
    vcmi-mod-new-old-spells-plus = {
      url = "github:vcmi-mods/new-old-spells-plus/vcmi-1.7";
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

    # macOS hosts. nixpkgs-*-darwin is the same release as nixpkgs above but
    # gated on Darwin Hydra jobs, so the binary cache actually covers it.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # Determinate Nix on macOS. The installer (.pkg, MDM-deployable) owns the
    # Nix daemon and /etc/nix/nix.conf; this flake only contributes the
    # nix-darwin module, which sets `nix.enable = false` and exposes
    # `determinateNix.customSettings` (rendered to /etc/nix/nix.custom.conf).
    # Its own nixpkgs is deliberately not followed: Determinate only tests
    # determinate-nixd against its own lock.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
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
    opentyrian2000-engaged,
    wazuh-agent,
    nix-darwin,
    determinate,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    # lnxlink is a non-flake source input; the packaging lives beside its
    # module. Exposing it as pkgs.lnxlink keeps the input out of specialArgs
    # and lets the module consume it through a normal `package` option.
    lnxlinkOverlay = final: _: {
      lnxlink = final.callPackage ./modules/apps/lnxlink/package.nix {src = lnxlink;};
    };
    # Non-flake game sources (see the inputs). vcmiMods maps VCMI mod id ->
    # source tree, collected from every vcmi-mod-* input.
    gamesOverlay = final: _: {
      opentyrian2000-engaged = final.callPackage ./modules/system/gaming/opentyrian2000-engaged.nix {src = opentyrian2000-engaged;};
      vcmiMods =
        nixpkgs.lib.mapAttrs' (name: src: nixpkgs.lib.nameValuePair (nixpkgs.lib.removePrefix "vcmi-mod-" name) src)
        (nixpkgs.lib.filterAttrs (name: _: nixpkgs.lib.hasPrefix "vcmi-mod-" name) inputs);
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
      # The scope also has to carry upstream's shared helpers (platformSource,
      # mkUpdater, fetchurlTemplate, ...). Hand-listing those is the same trap
      # as hand-listing package arguments -- it broke again when opencode
      # gained `mkUpdater`. So derive them from lib/ too: every lib/<foo-bar>.nix
      # becomes scope.fooBar, and the ones that take an argument set are put
      # through callPackage so *their* dependencies also resolve by name from
      # the scope (mk-updater wants `lib`, platform-source wants `stdenv` and
      # `fetchurlTemplate`, and so on). A new helper upstream adds needs no
      # change here; it just appears in the scope under its camelCased name.
      #
      # default.nix is upstream's extended lib, not a scope helper -- it wants
      # the flake `inputs` we don't have, and `flake` below covers its only use.
      libNames =
        builtins.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name)
        (builtins.attrNames (builtins.readDir (llm-agents + "/lib")));
      libHelpers = self:
        lib.listToAttrs (map (
            fileName: let
              path = llm-agents + "/lib/${fileName}";
              # foo-bar.nix -> fooBar, matching the names upstream's own flake
              # binds these helpers to.
              base = lib.removeSuffix ".nix" fileName;
              parts = lib.splitString "-" base;
              camel = lib.concatStrings (lib.take 1 parts ++ map lib.toSentenceCase (lib.drop 1 parts));
            in
              lib.nameValuePair camel (
                # Curried helpers (interpolate) take no argument set, so
                # callPackage would apply them to `{}` and hand back a
                # half-applied function; import those as-is.
                if builtins.functionArgs (import path) == {}
                then import path
                else self.callPackage path {}
              )
          )
          libNames);
      scope = lib.makeScope final.newScope (
        self:
          libHelpers self
          // {
            system = final.stdenv.hostPlatform.system;
            # Upstream reads `flake.lib.licenses.unfree` in meta only. llm-agents
            # is a non-flake source input here, so hand it nixpkgs lib, which has
            # licenses.unfree, rather than the flake's own extended lib.
            flake = {inherit lib;};
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
    wazuhOverlay = final: _: {
      wazuh-agent = wazuh-agent.packages.${final.stdenv.hostPlatform.system}.wazuh-agent;
    };
  in {
    nixosConfigurations = {
      dinth-nixos-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          machineType = "desktop";
          isDarwin = false;
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
            nixpkgs.overlays = [lnxlinkOverlay gamesOverlay llmAgentsOverlay wazuhOverlay];
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
          isDarwin = false;
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
            nixpkgs.overlays = [lnxlinkOverlay gamesOverlay wazuhOverlay];
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
          isDarwin = false;
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
            nixpkgs.overlays = [lnxlinkOverlay gamesOverlay llmAgentsOverlay wazuhOverlay];
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

    # `nix fmt -- .` formats every .nix file in the tree with alejandra -- the
    # same pinned build checks.format uses. The path is required: bare
    # `nix fmt` passes alejandra no arguments, so it reads stdin instead.
    formatter.${system} = pkgs.alejandra;

    # `nix flake check` — host evals + repo-wide lints.
    checks.${system} = {
      # Verify each host configuration evaluates and builds.
      dinth-nixos-desktop = self.nixosConfigurations.dinth-nixos-desktop.config.system.build.toplevel;
      michal-surface-go = self.nixosConfigurations.michal-surface-go.config.system.build.toplevel;
      r230-nixos = self.nixosConfigurations.r230-nixos.config.system.build.toplevel;
      # The Mac can't be built here, and its toplevel can't even be fully
      # evaluated: catppuccin's palette and zsh's vivid LS_COLORS are
      # import-from-derivation, so they need an aarch64-darwin builder.
      # Evaluating the rest still runs the module system's option checks, so a
      # NixOS-only option leaking into a shared module (or a package broken
      # on Darwin) fails here before anyone runs darwin-rebuild. Context is
      # discarded so the check never tries to realise Darwin derivations.
      michal-macbook-pro-eval = let
        inherit (nixpkgs) lib;
        inherit (self.darwinConfigurations.michal-macbook-pro) config;
        user = config.primaryUser.name;
        hm = config.home-manager.users.${user};
        # Assertions normally only fire when toplevel is built, which can't
        # happen here, so surface the system and Home Manager ones directly.
        failed = map (a: a.message) (
          builtins.filter (a: !a.assertion) (config.assertions ++ hm.assertions)
        );
        # Everything below is forced except what reaches the IFD above:
        # hm-session-vars.sh, ~/.zshenv (which sources it) and the fonts
        # marker carry the palette or LS_COLORS, and these activation steps
        # and the per-user profile bundle the whole Home Manager generation.
        ifd = {
          hmPackages = ["hm-session-vars.sh"];
          hmFiles = ["./.zshenv" "Library/Fonts/.home-manager-fonts-version"];
          hmActivation = ["checkFilesChanged" "copyApps" "onFilesChange"];
          etc = ["profiles/per-user/${user}"];
        };
        # Forcing a drvPath evaluates the derivation and all its inputs, which
        # is where a Linux-only package or an option type clash surfaces.
        # Home Manager's half used to be left out, so two of those (zsh's
        # wl-clipboard pbcopy, bat's map-syntax vs Ghostty) went unnoticed.
        drvPaths = map (p: p.drvPath);
        sources = files:
          lib.mapAttrs (_: f: f.source.drvPath or (toString f.source))
          (lib.filterAttrs (_: f: f.enable) files);
      in
        assert lib.assertMsg (failed == []) "michal-macbook-pro assertions failed:\n${lib.concatStringsSep "\n" failed}";
          pkgs.writeText "michal-macbook-pro-eval" (builtins.unsafeDiscardStringContext (builtins.toJSON {
            inherit (config.system) stateVersion;
            systemPackages = drvPaths config.environment.systemPackages;
            etc = sources (removeAttrs config.environment.etc ifd.etc);
            nixCustomConf = config.environment.etc."nix/nix.custom.conf".text;
            launchdDaemons = lib.mapAttrs (_: d: d.serviceConfig) config.launchd.daemons;
            hmPackages = drvPaths (builtins.filter (p: !builtins.elem p.name ifd.hmPackages) hm.home.packages);
            hmFiles = sources (removeAttrs hm.home.file ifd.hmFiles);
            hmActivation = lib.mapAttrs (_: a: a.data) (removeAttrs hm.home.activation ifd.hmActivation);
            hmLaunchdAgents = lib.mapAttrs (_: a: a.config) hm.launchd.agents;
          }));

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

    darwinConfigurations = {
      michal-macbook-pro = nix-darwin.lib.darwinSystem {
        specialArgs = {
          machineType = "laptop";
          isDarwin = true;
          inherit catppuccin home-manager;
        };
        modules = [
          ./libs
          ./modules
          ./hosts/michal-macbook-pro/configuration.nix
          determinate.darwinModules.default
          agenix.darwinModules.default
          nix-index-database.darwinModules.nix-index
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = [gamesOverlay llmAgentsOverlay];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              sharedModules = [agenix.homeManagerModules.default];
            };
          }
        ];
      };
    };
  };
}
