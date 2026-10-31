# Deploy this profile's folders into ~/.config, one entry per folder.
# Add a folder to profiles/nixos/, rebuild, and it is deployed; nothing to list.
# Only used by the NixOS configuration; the standalone profile on non-NixOS
# systems leaves ~/.config alone.
#
# profile.conf defines groups of alternative apps ("group.terminal = kitty foot")
# and picks one ("terminal = kitty"): of each group only the chosen folder is
# deployed. The same file drives dotfiles.bash, so there is one source of truth.
{ dotfiles, lib, ... }:

let
  profile = "${dotfiles}/profiles/nixos";

  # "key = value  # comment" lines -> [ { name = "key"; value = "value"; } ]
  confPath = "${profile}/profile.conf";
  confLines =
    if builtins.pathExists confPath then lib.splitString "\n" (builtins.readFile confPath) else [ ];
  parseLine =
    line:
    let
      m = builtins.match "[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*" (
        builtins.head (lib.splitString "#" line)
      );
    in
    if m == null then [ ] else [ { name = builtins.elemAt m 0; value = builtins.elemAt m 1; } ];
  entries = lib.concatMap parseLine confLines;

  words = value: lib.filter (w: w != "") (lib.splitString " " value);
  isGroup = e: lib.hasPrefix "group." e.name;
  groups = lib.listToAttrs (
    map (e: { name = lib.removePrefix "group." e.name; value = words e.value; }) (lib.filter isGroup entries)
  );
  prefs = lib.listToAttrs (map (e: { inherit (e) name; value = lib.head (words e.value); }) (lib.filter (e: !(isGroup e)) entries));

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
