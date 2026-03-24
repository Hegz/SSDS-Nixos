{
  description = "SSDS NixOS configuration for Raspberry Pi 4";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";

    home-manager = {
      url = "github:nix-community/home-manager/cf9686ba26f5ef788226843bc31fda4cf72e373b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/2d4b4717b2534fad5c715968c1cece04a172b365";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix/632c3161a6cc24142c8e3f5529f5d81042571165";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, sops-nix, ... }: {
    nixosConfigurations.nixos-ssds = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        home-manager.nixosModules.home-manager
        nixos-hardware.nixosModules.raspberry-pi-4
        sops-nix.nixosModules.sops
      ];
    };
  };
}
