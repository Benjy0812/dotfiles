{ inputs, pkgs, ... }:

{
  home.username = "benjy";
  home.homeDirectory = "/home/benjy";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = [
    inputs.zen-browser.packages.${pkgs.system}.default

    # Star Citizen
    inputs.nix-citizen.packages.${pkgs.system}.rsi-launcher
  ];
}
