{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Version control
    git
    github-cli

    # Nodes
    nodejs
    bun
  ];
}
