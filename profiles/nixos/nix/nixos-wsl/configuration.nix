{ config, lib, pkgs, ... }:

{
  imports = [
    <nixos-wsl/modules>
    ./modules/dev.nix
    ./modules/packages.nix
    ./modules/shell.nix
  ];

  # WSL specific
  wsl.enable = true;
  wsl.defaultUser = "nixos";

  # System
  system.stateVersion = "26.05";

  # Basic settings
  time.timeZone = "Europe/Oslo";

  # Users
  users.users.nixos = {
    isNormalUser = true;
    home = "/home/nixos";
    shell = pkgs.fish;
  };
}
