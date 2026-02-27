{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:nixos/nixos-hardware/master"; # Hardware Specific Configurations
    catppuccin.url = "github:catppuccin/nix/release-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager/d4fae34";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    agenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

#     nix-darwin = {
#       url = "github:nix-darwin/nix-darwin/master";
#       inputs.nixpkgs.follows = "nixpkgs";
#     };
  };

  outputs =
    inputs@{ self, nixpkgs, home-manager, plasma-manager, catppuccin, agenix, nixos-hardware, ... }:
    {
      nixosConfigurations = {
        dinth-nixos-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { machineType = "desktop"; inherit catppuccin; };
          modules = [
            ./libs
            ./modules
            ./hosts/dinth-nixos-desktop/configuration.nix
            agenix.nixosModules.default
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager agenix.homeManagerModules.default ];
            }
          ];
        };
        r230-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { machineType = "server"; inherit catppuccin; };
          modules = [
            ./libs
            ./modules
            ./hosts/r230-nixos/configuration.nix
            agenix.nixosModules.default
            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [ agenix.homeManagerModules.default ];
            }
          ];
        };
        michal-surface-go = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { machineType = "tablet"; inherit catppuccin; };
            modules = [
              ./libs
              ./modules
              ./hosts/michal-surface-go/configuration.nix
              agenix.nixosModules.default
              catppuccin.nixosModules.catppuccin
              nixos-hardware.nixosModules.microsoft-surface-go
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager agenix.homeManagerModules.default ];
              }
            ];
          };
        };

      # Flake checks - run with: nix flake check
      checks.x86_64-linux = {
        # Verify each host configuration evaluates successfully
        dinth-nixos-desktop = self.nixosConfigurations.dinth-nixos-desktop.config.system.build.toplevel;
        michal-surface-go = self.nixosConfigurations.michal-surface-go.config.system.build.toplevel;
        r230-nixos = self.nixosConfigurations.r230-nixos.config.system.build.toplevel;
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
