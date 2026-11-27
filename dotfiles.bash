#!/usr/bin/env bash
# dotfiles: link common/ and the active profile (profiles/<os>/) into ~/.config
# with GNU stow.
# git is the sync, history and undo. Run `./dotfiles.bash help`.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CONFIG/hypr"
PROFILE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/profile"

die() { echo "$*" >&2; exit 1; }
short() { echo "${1/#$HOME/\~}"; }

usage() {
  cat <<EOF
dotfiles: link common/ and profiles/<os>/ into ~/.config (one link per file, via stow)

  bootstrap       new machine: install packages.txt, link, setup (Omarchy), doctor
  link [-n]       link the profile into ~/.config (-n: dry run)
  adopt           first run on a machine: move existing ~/.config files into the
                  repo, then link them (review with git diff, git restore to drop)
  unlink          remove the links (the repo keeps the files)
  track PATH..    move a ~/.config file into the profile and link it back
  doctor          report broken links, unlinked repo files and link conflicts
  snapshot        copy per-machine files (shell.json...) to machines/<host>/
  setup           Omarchy: load custom.lua from hyprland.lua, build benjy.bar (after link)
  bar-update      Omarchy: rebuild benjy.bar from the stock bar + bar.patch
  bar-save        Omarchy: save edits to the live benjy.bar Bar.qml as bar.patch
  uninstall       Omarchy: remove those hooks
  rebuild [-n]    NixOS: nixos-rebuild switch for this repo's flake (-n: dry-build)
  profile [NAME|auto]  show or set this machine's profile
  help
EOF
}

# First profile folder that fits this machine: Omarchy, NixOS, then the distro.
detect_profile() {
  local c ids cands=()
  if [[ -d $CONFIG/omarchy ]]; then cands+=(omarchy); fi
  if [[ -e /etc/NIXOS ]]; then cands+=(nixos nix); fi
  # shellcheck source=/dev/null
  if [[ -r /etc/os-release ]]; then ids=$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}"); read -ra ids <<<"$ids"; cands+=("${ids[@]}"); fi
  for c in "${cands[@]}"; do
    if [[ -d $ROOT/profiles/$c ]]; then echo "$c"; return 0; fi
  done
}

resolve_profile() {
  local want=${DOTFILES_PROFILE:-}
  if [[ -z $want && -f $PROFILE_FILE ]]; then want=$(<"$PROFILE_FILE"); fi
  if [[ ${want:-auto} == auto ]]; then PROFILE=$(detect_profile); else PROFILE=$want; fi
  if [[ -n $PROFILE && ! -d $ROOT/profiles/$PROFILE ]]; then PROFILE=; fi
}
resolve_profile
P="$ROOT/profiles/$PROFILE"

# A profile with a nix/ folder is deployed by home-manager (nixos-rebuild).
nix_managed() { [[ -n $PROFILE && -d $P/nix ]]; }

# Two stow layers: common/ (shared by every profile), then profiles/<os>/.
# A file in the profile replaces the same file in common/, which is skipped.
STOW_IGNORE=(--ignore='README\.md' --ignore='fish_variables' --ignore='^packages\.txt')

profile_files() { [[ -d $P ]] && (cd "$P" && find . \( -type f -o -type l \) -printf '%P\n'); }

common_ignores() { # profile files as stow --ignore args for common/
  local f
  # shellcheck disable=SC2001 # a regex escape; ${f//} cannot do a char class
  while IFS= read -r f; do
    printf -- "--ignore=^%s\n" "$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<<"$f")"
  done < <(profile_files)
}

# A common/ link for a file the profile now has would block the profile link.
drop_overridden() {
  local f t
  while IFS= read -r f; do
    t=$CONFIG/$f
    if [[ -L $t && $(readlink -f "$t") == "$ROOT/common/$f" ]]; then rm -- "$t"; fi
  done < <(profile_files)
}

stow_profile() { # [-n|-D|--adopt] [-v]
  [[ -n $PROFILE ]] || die "no profile for this machine; set one: $0 profile NAME"
  nix_managed && die "profile '$PROFILE' is deployed by home-manager; run: $0 rebuild"
  command -v stow >/dev/null || die "stow not found: sudo pacman -S stow"
  mkdir -p "$CONFIG"
  local -a ign
  mapfile -t ign < <(common_ignores)
  local s=(stow --no-folding "${STOW_IGNORE[@]}" -t "$CONFIG")
  if [[ " $* " == *" -D "* ]]; then
    "${s[@]}" "$@" -d "$ROOT/profiles" "$PROFILE"
    if [[ -d $ROOT/common ]]; then "${s[@]}" "$@" -d "$ROOT" common; fi
    return
  fi
  if [[ " $* " != *" -n "* ]]; then drop_overridden; fi
  if [[ -d $ROOT/common ]]; then "${s[@]}" "${ign[@]}" "$@" -d "$ROOT" common; fi
  "${s[@]}" "$@" -d "$ROOT/profiles" "$PROFILE"
}

track() {
  local path rel
  stow_profile -n 2>/dev/null || die "link fails before tracking; fix that first: $0 link -n"
  for path in "$@"; do
    [[ $path == /* ]] || path=$CONFIG/$path
    rel=${path#"$CONFIG"/}
    [[ $rel != "$path" && -e $path ]] || die "not a file under $(short "$CONFIG"): $path"
    [[ -L $path ]] && die "already a link: $(short "$path")"
    [[ -e $P/$rel ]] && die "already in the repo: profiles/$PROFILE/$rel"
    mkdir -p "$(dirname -- "$P/$rel")"
    mv -- "$path" "$P/$rel"
    echo "tracked $rel"
  done
  stow_profile
}

# Per-machine files that stay real files in ~/.config (apps rewrite them), so
# they are copied to machines/<host>/ as a backup instead of linked.
SNAPSHOT=(omarchy/shell.json hypr/bindings.lua hypr/monitors.lua)

snapshot() {
  local host=${DOTFILES_HOST:-$(hostname)} rel n=0
  for rel in "${SNAPSHOT[@]}"; do
    [[ -f $CONFIG/$rel ]] || continue
    mkdir -p "$(dirname -- "$ROOT/machines/$host/$rel")"
    cp -- "$CONFIG/$rel" "$ROOT/machines/$host/$rel"
    echo "copied $rel"
    ((++n))
  done
  ((n)) && echo "to machines/$host/; commit to keep it" || echo "nothing to copy"
}

# Report broken links into the repo, repo files that are not linked, and
# anything that would stop `link`. Exit 1 if there is something to fix.
doctor() {
  local f t bad=0 out
  while IFS= read -r t; do
    [[ $(readlink -m "$t") == "$ROOT"/* ]] || continue
    echo "broken link: $(short "$t")"
    bad=1
  done < <(find "$CONFIG" -xtype l 2>/dev/null)
  nix_managed && { ((bad == 0)) && echo "ok (home-manager deploys this profile)"; return "$bad"; }
  while IFS= read -r f; do
    case $f in */README.md | README.md | */fish_variables | */.gitignore | packages.txt) continue ;; esac # stow skips these
    if [[ -e $P/$f ]]; then t=$P/$f; else t=$ROOT/common/$f; fi
    [[ -L $CONFIG/$f && $(readlink -f "$CONFIG/$f") == "$(readlink -f "$t")" ]] && continue
    echo "not linked: $f"
    bad=1
  done < <({ profile_files; [[ -d $ROOT/common ]] && (cd "$ROOT/common" && find . \( -type f -o -type l \) -printf '%P\n'); } | sort -u)
  if ! out=$(stow_profile -n 2>&1); then
    echo "link would fail:"
    echo "$out" | grep -v '^LINK\|^MKDIR\|^All operations'
    bad=1
  fi
  ((bad == 0)) && echo "ok"
  return "$bad"
}

# profiles/<os>/packages.txt: one or more names per line, "aur:name" for AUR
# packages, # comments. Installed with Omarchy's helpers, pacman or apt.
install_packages() {
  local list=$P/packages.txt line w
  local -a repo=() aur=()
  [[ -f $list ]] || { echo "no packages.txt in profiles/$PROFILE; skipping packages"; return 0; }
  while IFS= read -r line; do
    for w in ${line%%#*}; do
      if [[ $w == aur:* ]]; then aur+=("${w#aur:}"); else repo+=("$w"); fi
    done
  done <"$list"
  if command -v omarchy-pkg-add >/dev/null; then
    if ((${#repo[@]})); then omarchy-pkg-add "${repo[@]}"; fi
    if ((${#aur[@]})); then omarchy-pkg-aur-add "${aur[@]}"; fi
  elif command -v pacman >/dev/null; then
    if ((${#repo[@]})); then sudo pacman -S --needed "${repo[@]}"; fi
    if ((${#aur[@]})); then echo "install from the AUR yourself: ${aur[*]}"; fi
  elif command -v apt-get >/dev/null; then
    if ((${#repo[@]})); then sudo apt-get install -y "${repo[@]}"; fi
  else
    echo "no known package manager; install yourself: ${repo[*]} ${aur[*]}"
  fi
}

# A new machine in one go: packages, links, Omarchy hooks, then a health check.
bootstrap() {
  if nix_managed; then rebuild; return; fi
  install_packages
  stow_profile
  echo "linked common/ and profiles/$PROFILE/"
  if [[ -f $P/hypr/custom.lua && -d $P/omarchy/plugins && -f $HYPR/hyprland.lua ]]; then omarchy_setup; fi
  doctor || echo "doctor found something to fix (above)"
}

# ---- omarchy ----------------------------------------------------------------
# stow links the plugins and hypr settings; setup adds the hook it cannot.
# custom.lua loads each plugin's Hyprland-side Lua itself (one dofile per plugin).

omarchy_plugins() {
  local d
  for d in "$P"/omarchy/plugins/*/; do [[ -d $d ]] && basename "$d"; done
}

# Drop a plugin's marked block from a hook file (hooks older setups added).
remove_hook() { # file id
  [[ -f $1 ]] || return 0
  grep -qxF -- "-- >>> $2 >>>" "$1" || return 0
  cp "$1" "$1.bak"
  awk -v b="-- >>> $2 >>>" -v e="-- <<< $2 <<<" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip
  ' "$1" >"$1.tmp"
  mv "$1.tmp" "$1"
  echo "  removed old autostart hook $2"
}

# benjy.bar is Omarchy's bar plus our edits. The repo keeps only the edits
# (bar.patch) and our own files; bar-update rebuilds the rest from the stock bar
# into ~/.config as real files, so an Omarchy update to the bar is one command.
BAR_STOCK=${DOTFILES_STOCK_BAR:-/usr/share/omarchy/shell/plugins/bar}

bar_update() {
  local src=$P/omarchy/plugins/benjy.bar dest=$CONFIG/omarchy/plugins/benjy.bar tmp f
  [[ -f $src/bar.patch ]] || die "no $(short "$src")/bar.patch"
  [[ -f $BAR_STOCK/Bar.qml ]] || die "no stock bar at $(short "$BAR_STOCK")"
  tmp=$(mktemp -d)
  cp -r "$BAR_STOCK"/. "$tmp"
  if ! patch -s -d "$tmp" -p1 -r - --no-backup-if-mismatch <"$src/bar.patch" >/dev/null; then
    rm -rf "$tmp"
    die "bar.patch no longer applies to the stock Bar.qml (Omarchy changed it); the live bar is unchanged.
Redo the edits marked 'benjy' in $(short "$dest/Bar.qml") on a fresh copy of $(short "$BAR_STOCK/Bar.qml"), then: $0 bar-save"
  fi
  while IFS= read -r f; do
    [[ -e $src/$f ]] && continue # ours (manifest, README, AutoHide...) stays linked
    mkdir -p "$(dirname -- "$dest/$f")"
    rm -f -- "$dest/$f" # never write through a link into the repo
    cp -- "$tmp/$f" "$dest/$f"
  done < <(cd "$tmp" && find . -type f -printf '%P\n')
  rm -rf "$tmp"
  echo "benjy.bar rebuilt from $(short "$BAR_STOCK") + bar.patch"
}

# Save edits made to the live Bar.qml as the new bar.patch.
bar_save() {
  local src=$P/omarchy/plugins/benjy.bar dest=$CONFIG/omarchy/plugins/benjy.bar
  [[ -f $dest/Bar.qml ]] || die "no $(short "$dest/Bar.qml"); run: $0 bar-update"
  diff -u --label a/Bar.qml --label b/Bar.qml "$BAR_STOCK/Bar.qml" "$dest/Bar.qml" >"$src/bar.patch" || true
  echo "saved $(short "$src/bar.patch"); commit it"
}

omarchy_reload() {
  hyprctl reload >/dev/null 2>&1 && hyprctl configerrors || true
}

# Load custom.lua from hyprland.lua and build benjy.bar. Safe to run again,
# e.g. after `omarchy refresh hyprland`.
omarchy_setup() {
  local hl=$HYPR/hyprland.lua f
  [[ -f $hl ]] || die "missing $(short "$hl")"
  [[ -f $P/hypr/custom.lua && -d $P/omarchy/plugins ]] || die "the profile '${PROFILE:-none}' has no hypr/custom.lua and omarchy/plugins/"
  # The plugins must find their settings linked, or they create defaults.
  while read -r f; do
    [[ -d $CONFIG/omarchy/plugins/$f ]] || die "plugin $f is not linked; run: $0 link"
  done < <(omarchy_plugins)
  cp "$hl" "$hl.bak"
  # Skip Omarchy's preinstalled app binds; has to be set before its defaults load.
  sed -i 's/^-- *omarchy_preinstalled_bindings = false/omarchy_preinstalled_bindings = false/' "$hl"
  sed -i '\|^dofile(.*/hypr/custom\.lua")$|d' "$hl"
  echo "dofile(\"$P/hypr/custom.lua\")" >>"$hl"
  echo "  hook    custom.lua loads from hyprland.lua"
  while read -r f; do remove_hook "$HYPR/autostart.lua" "$f"; done < <(omarchy_plugins)
  if [[ -f $P/omarchy/plugins/benjy.bar/bar.patch ]]; then bar_update; fi
  omarchy_reload
}

omarchy_uninstall() {
  local hl=$HYPR/hyprland.lua f
  while read -r f; do remove_hook "$HYPR/autostart.lua" "$f"; done < <(omarchy_plugins)
  if [[ -f $hl ]]; then
    cp "$hl" "$hl.bak"
    sed -i '\|^dofile(.*/hypr/custom\.lua")$|d' "$hl"
    sed -i 's/^omarchy_preinstalled_bindings = false/-- omarchy_preinstalled_bindings = false/' "$hl"
  fi
  omarchy_reload
  echo "removed the Omarchy hooks (links stay; $0 unlink removes them)"
}

rebuild() { # [-n]
  local host hosts flake args keepalive
  nix_managed || die "rebuild is for a Nix-managed profile (one with a nix/ folder); the active profile is '${PROFILE:-none}'"
  command -v nixos-rebuild >/dev/null || die "nixos-rebuild not found; this is not NixOS"
  host=${DOTFILES_NIX_HOST:-}
  if [[ -z $host ]]; then
    # Prefer the hosts/ folder named like this machine, else the first one.
    hosts=$ROOT/profiles/nixos/nix/hosts
    host=$(hostname)
    [[ -d $hosts/$host ]] || host=$(find "$hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | head -n1)
    [[ -n $host ]] || die "no host folder in profiles/nixos/nix/hosts/"
  fi
  flake="$ROOT#$host"
  # Build as this user and let nixos-rebuild sudo only for the switch: Nix
  # refuses a git repo owned by someone else, so `sudo nixos-rebuild` fails
  # with "not owned by current user". --impure lets the host read this
  # machine's /etc/nixos/hardware-configuration.nix.
  args=(--flake "$flake" --impure)
  # Without a network, build from what is already in the Nix store instead of
  # failing on downloads (the flake inputs are kept there, see configuration.nix).
  if ! timeout 3 getent hosts cache.nixos.org >/dev/null 2>&1; then
    echo "No network: rebuilding offline from the Nix store"
    args+=(--offline)
  fi
  if [[ ${1:-} == -n ]]; then
    echo "would run: nixos-rebuild dry-build ${args[*]}"
    nixos-rebuild dry-build "${args[@]}"
  else
    # Ask for the sudo password up front and keep it fresh while Nix builds,
    # so the switch at the end never stops to ask.
    sudo -v || die "sudo is needed to switch to the new system"
    while sleep 60; do sudo -n -v 2>/dev/null || exit; done &
    keepalive=$!
    trap 'kill $keepalive 2>/dev/null' EXIT
    nixos-rebuild switch "${args[@]}" --sudo
  fi
}

cmd=${1:-help}
shift || true
case $cmd in
  link) if [[ ${1:-} == -n ]]; then stow_profile -n -v; else stow_profile; fi ;;
  adopt)
    stow_profile --adopt
    echo "Adopted. Review with: git -C $(short "$ROOT") diff   (git restore what you do not want, then $0 link)"
    ;;
  unlink) stow_profile -D ;;
  track)
    (($#)) || die "usage: $0 track PATH.."
    track "$@"
    ;;
  bootstrap) bootstrap ;;
  doctor) doctor ;;
  snapshot) snapshot ;;
  bar-update) bar_update ;;
  bar-save) bar_save ;;
  setup) omarchy_setup ;;
  uninstall) omarchy_uninstall ;;
  rebuild) rebuild "$@" ;;
  profile)
    if (($#)); then
      [[ $1 == auto || -d $ROOT/profiles/$1 ]] || die "no profile '$1' in $(short "$ROOT/profiles")"
      mkdir -p "$(dirname -- "$PROFILE_FILE")"
      echo "$1" >"$PROFILE_FILE"
      resolve_profile
    fi
    echo "profile: ${PROFILE:-none}"
    ;;
  help | -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
