# Extra settings for the standalone home-manager profile, used on
# non-NixOS systems such as CachyOS. This profile installs packages only;
# it does not manage ~/.config (that would clobber this repository, which
# lives at ~/.config on those systems).
{ ... }:

{
  targets.genericLinux.enable = true;
}
