{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    catppuccin.url = "github:catppuccin/nix";
    home-manager = {
      url = "github:nix-community/home-manager/35e1f5a7c29f2b05e8f53177f6b5c71108c5f4c3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, plasma-manager, catppuccin, agenix, nix-darwin, ... }:
    {
      nixosConfigurations = {
        dinth-nixos-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { machineType = "desktop"; };
          modules = [
            ./libs
            ./modules
            ./hosts/dinth-nixos-desktop/configuration.nix
            agenix.nixosModules.default
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              #home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager agenix.homeManagerModules.default];
              home-manager.users.michal = {
                imports = [
                  catppuccin.homeModules.catppuccin
                ];
              };
              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
          ];
        };
        r230-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { machineType = "server"; };
          modules = [
            ./libs
            ./modules
            ./hosts/r230-nixos/configuration.nix
            agenix.nixosModules.default
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              #home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [ agenix.homeManagerModules.default];
              home-manager.users.michal = {
                imports = [
                  catppuccin.homeModules.catppuccin
                ];
              };
              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
          ];
        };
      };
      darwinConfigurations = {
        michal-macbook-pro = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { machineType = "laptop"; };
          modules = [
            ./libs
            ./modules
            ./hosts/michal-macbook-pro/configuration.nix
            agenix.nixosModules.default
#            catppuccin.nixosModules.catppuccin
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.verbose = true;
              home-manager.users.michal = {
                imports = [
                  catppuccin.homeModules.catppuccin
                ];
              };
            }
          ];
        };
      };
    };
}
