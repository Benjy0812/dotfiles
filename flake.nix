{
  description = "Benjy's dotfiles: NixOS system, MangoWM session and home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # `dotfiles` is this repository, so the configs can be deployed straight
      # from the flake without cloning it onto the target machine.
      specialArgs = {
        inherit inputs;
        dotfiles = self;
      };
    in {
      nixosConfigurations.benjy = nixpkgs.lib.nixosSystem {
        inherit system;
        inherit specialArgs;

        modules = [
          ./nix/nixos/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Back up pre-existing files instead of failing the switch.
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.benjy = {
              imports = [
                ./nix/nixos/home.nix
                ./nix/nixos/dotfiles.nix
              ];
            };
          }
        ];
      };

      # Standalone profile for non-NixOS machines (e.g. CachyOS).
      # Installs packages only and never touches ~/.config.
      homeConfigurations.benjy = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = specialArgs;
        modules = [
          ./nix/nixos/home.nix
          ./nix/nixos/standalone.nix
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
