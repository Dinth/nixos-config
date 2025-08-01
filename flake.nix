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
          #inherit "x86_64-linux";
          modules = [
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
                  ./modules/home-manager/home.nix
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
        michal-macbook-pro = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/michal-macbook-pro/configuration.nix
            agenix.nixosModules.default
            catppuccin.nixosModules.catppuccin
          ];
        };
      };
    };
}
