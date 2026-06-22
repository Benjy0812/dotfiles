{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Essential
    neovim
    git
    unzip
    curl
    wget
    fish

    # Editor
    zed
    package-version-server

    # Nix tools
    nil
    nixpkgs-fmt

    # Utilities
    btop
    tree
    fd
  ];
}
