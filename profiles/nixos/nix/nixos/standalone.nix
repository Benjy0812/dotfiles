# Extra settings for the standalone home-manager profile, used on
# non-NixOS systems such as CachyOS. This profile installs packages only;
# it does not manage ~/.config, so configs kept there by hand are never
# overwritten.
{ ... }:

{
  targets.genericLinux.enable = true;
}
