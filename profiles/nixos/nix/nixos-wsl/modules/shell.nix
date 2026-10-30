{ config, pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx EDITOR zed
      set fish_greeting ""
    '';

    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      nr = "sudo nixos-rebuild switch";
      nrd = "sudo nixos-rebuild dry-build";
      nd = "nix develop";
    };
  };

  environment.systemPackages = with pkgs; [
    fish
  ];
}
