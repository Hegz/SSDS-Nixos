{
  description = "SSDS NixOS configuration for Raspberry Pi 4";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix/";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, sops-nix, ... }:
    let
      # self.rev / self.lastModifiedDate only exist for a clean, committed
      # working tree. A dirty checkout falls back to obvious placeholders
      # rather than silently lying about what was actually built.
      gitRev = self.rev or "dirty";
      gitShortRev = if self ? rev then builtins.substring 0 7 self.rev else "dirty";
      rawDate = self.lastModifiedDate or "00000000000000";
      gitDate =
        if self ? lastModifiedDate then
          "${builtins.substring 0 4 rawDate}-${builtins.substring 4 2 rawDate}-${builtins.substring 6 2 rawDate}"
        else "unknown";
    in
    {
      nixosConfigurations.nixos-ssds = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit gitRev gitShortRev gitDate; };
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
