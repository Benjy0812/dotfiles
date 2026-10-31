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

      # The one account the configs are built for.
      username = "benjy";

      # `dotfiles` is this repository, so the configs can be deployed straight
      # from the flake without cloning it onto the target machine.
      specialArgs = {
        inherit inputs username;
        dotfiles = self;
      };

      # One NixOS configuration per folder in profiles/nixos/nix/hosts/, so a new
      # machine is a new folder; nothing here needs editing. Hardware comes from
      # each machine's /etc/nixos/hardware-configuration.nix (build with --impure).
      hostsDir = ./profiles/nixos/nix/hosts;

      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;

          modules = [
            ./profiles/nixos/nix/configuration.nix
            (hostsDir + "/${name}")

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Back up pre-existing files instead of failing the switch.
              home-manager.backupFileExtension = "hm-backup";
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.users.${username} = {
                imports = [
                  ./profiles/nixos/nix/home.nix
                  ./profiles/nixos/nix/dotfiles.nix
                ];
              };
            }
          ];
        };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs (name: _: mkHost name) (
        nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir hostsDir)
      );

      # Standalone profile for non-NixOS machines (e.g. CachyOS).
      # Installs packages only and never touches ~/.config.
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = specialArgs;
        modules = [
          ./profiles/nixos/nix/home.nix
          ./profiles/nixos/nix/standalone.nix
        ];
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
