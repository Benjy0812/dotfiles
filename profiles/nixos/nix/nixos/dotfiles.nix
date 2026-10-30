# Deploy this profile's folders into ~/.config, one entry per folder.
# Add a folder to profiles/nixos/, rebuild, and it is deployed; nothing to list.
# Only used by the NixOS configuration; the standalone profile on non-NixOS
# systems leaves ~/.config alone.
#
# profile.conf (preferred terminal, editor, window manager) is honored: of each
# group only the chosen folder is deployed. Keep the groups in sync with
# PREF_* in dotfiles.bash.
{ dotfiles, lib, ... }:

let
  profile = "${dotfiles}/profiles/nixos";

  groups = {
    terminal = [ "alacritty" "kitty" "foot" "ghostty" ];
    editor = [ "nvim" "zed" ];
    wm = [ "hypr" "mango" "i3" "sway" "niri" "bspwm" "awesome" "river" "openbox" ];
  };

  # "terminal = kitty  # comment" lines -> { terminal = "kitty"; }
  confPath = "${profile}/profile.conf";
  confLines =
    if builtins.pathExists confPath then lib.splitString "\n" (builtins.readFile confPath) else [ ];
  parseLine =
    line:
    let
      m = builtins.match "[[:space:]]*([a-z]+)[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*" (
        builtins.head (lib.splitString "#" line)
      );
    in
    if m == null then [ ] else [ { name = builtins.elemAt m 0; value = builtins.elemAt m 1; } ];
  prefs = lib.listToAttrs (lib.concatMap parseLine confLines);

  # Folders of the profile, except nix/ itself (this configuration).
  folders = lib.filterAttrs (name: type: type == "directory" && name != "nix") (builtins.readDir profile);

  # Group members that lose to the chosen one (only if the chosen one exists).
  skipped = lib.concatLists (
    lib.mapAttrsToList (
      group: members:
      let
        want = prefs.${group} or "all";
      in
      if want == "all" || !(folders ? ${want}) then [ ] else lib.filter (m: m != want) members
    ) groups
  );

  deployed = lib.filterAttrs (name: _: !(builtins.elem name skipped)) folders;
in
{
  # Recursive so each directory stays writable (fish writes fish_variables,
  # Noctalia generates mango/noctalia.conf).
  xdg.configFile = lib.mapAttrs (name: _: {
    source = "${profile}/${name}";
    recursive = true;
  }) deployed;
}
