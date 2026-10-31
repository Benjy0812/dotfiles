# Machine-specific settings for this host. Copy this folder to hosts/<name>/ for
# a new machine (see ../../README.md).
{ ... }:

let
  # Disks, kernel modules and CPU come from the file the NixOS installer writes
  # on each machine, so a reinstall never boots with stale disk UUIDs. Reading
  # /etc needs --impure, which `./dotfiles.bash rebuild` passes.
  hardware = /etc/nixos/hardware-configuration.nix;
in
{
  imports =
    if builtins.pathExists hardware then
      [ hardware ]
    else
      throw "${toString hardware} is missing: run `sudo nixos-generate-config` to create it, then rebuild with --impure";

  networking.hostName = "Benjy-NixOS";

  # 16 GiB swap file as a safety net
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB
    }
  ];
}
