# Machine-specific settings for this host. Copy this folder to hosts/<name>/ for
# a new machine and replace hardware-configuration.nix (see ../../README.md).
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "Benjy-NixOS";

  # 16 GiB swap file as a safety net
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB
    }
  ];
}
