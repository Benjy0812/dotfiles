#!/usr/bin/env bash
# dotfiles: link the active profile (profiles/<os>/) into ~/.config with GNU stow.
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
dotfiles: link profiles/<os>/ into ~/.config (one link per file, via stow)

  link [-n]       link the profile into ~/.config (-n: dry run)
  adopt           first run on a machine: move existing ~/.config files into the
                  repo, then link them (review with git diff, git restore to drop)
  unlink          remove the links (the repo keeps the files)
  track PATH..    move a ~/.config file into the profile and link it back
  setup           Omarchy: hook custom.lua and the plugins into Hyprland (after link)
  uninstall       Omarchy: remove those hooks
  rebuild [-n]    NixOS: nixos-rebuild switch for this repo's flake (-n: dry-build)
  profile [NAME|auto]  show or set this machine's profile
  help
EOF
}

# First profile folder that fits this machine: Omarchy, NixOS, then the distro.
detect_profile() {
  local c id cands=()
  if [[ -d $CONFIG/omarchy ]]; then cands+=(omarchy); fi
  if [[ -e /etc/NIXOS ]]; then cands+=(nixos nix); fi
  if [[ -r /etc/os-release ]]; then id=$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}"); read -ra id <<<"$id"; cands+=("${id[@]}"); fi
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

stow_profile() {
  [[ -n $PROFILE ]] || die "no profile for this machine; set one: $0 profile NAME"
  nix_managed && die "profile '$PROFILE' is deployed by home-manager; run: $0 rebuild"
  command -v stow >/dev/null || die "stow not found: sudo pacman -S stow"
  mkdir -p "$CONFIG"
  stow --no-folding --ignore='README\.md' -d "$ROOT/profiles" -t "$CONFIG" "$@" "$PROFILE"
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

# ---- omarchy --------------------------------------------------------------
# stow links the plugins and hypr settings; setup adds the hooks it cannot.

omarchy_plugins() {
  local d
  for d in "$P"/omarchy/plugins/*/; do [[ -d $d ]] && basename "$d"; done
}

# Drop a plugin's marked block from a hook file.
remove_hook() { # file id
  [[ -f $1 ]] || return 0
  awk -v b="-- >>> $2 >>>" -v e="-- <<< $2 <<<" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip
  ' "$1" >"$1.tmp"
  mv "$1.tmp" "$1"
}

plugin_install() { # id
  local id=$1 hook=$HYPR/autostart.lua dest=$CONFIG/omarchy/plugins/$1
  [[ -f $hook ]] || { echo "  skipped plugin $id: $(short "$hook") is missing"; return 0; }
  cp "$hook" "$hook.bak"
  remove_hook "$hook" "$id"
  printf '%s\n' "-- >>> $id >>>" "dofile(\"$dest/${id#*.}.lua\")" "-- <<< $id <<<" >>"$hook"
  echo "  plugin  $id"
}

# The plugin files stay linked; `unlink` removes them.
plugin_uninstall() { # id
  remove_hook "$HYPR/autostart.lua" "$1"
  echo "  removed plugin hook $1"
}

omarchy_reload() {
  hyprctl reload >/dev/null 2>&1 && hyprctl configerrors || true
}

# Load custom.lua from hyprland.lua and hook the plugins into autostart.lua.
# Safe to run again, e.g. after `omarchy refresh hyprland`.
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
  # Plugins hook into autostart.lua: make sure it exists and hyprland.lua loads it.
  if [[ ! -f $HYPR/autostart.lua ]]; then
    cp /usr/share/omarchy/config/hypr/autostart.lua "$HYPR/autostart.lua" 2>/dev/null || echo "-- Extra autostart processes." >"$HYPR/autostart.lua"
    echo "  create  hypr/autostart.lua"
  fi
  if ! grep -q 'require("hypr.autostart")' "$hl"; then
    sed -i '/^require("hypr.looknfeel")/a require("hypr.autostart")' "$hl"
    grep -q 'require("hypr.autostart")' "$hl" || sed -i '\|^dofile(.*/hypr/custom\.lua")$|i require("hypr.autostart")' "$hl"
    echo "  hook    autostart.lua loads from hyprland.lua"
  fi
  while read -r f; do plugin_install "$f"; done < <(omarchy_plugins)
  omarchy_reload
}

omarchy_uninstall() {
  local hl=$HYPR/hyprland.lua f
  while read -r f; do plugin_uninstall "$f"; done < <(omarchy_plugins)
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
    [[ -d $hosts/$host ]] || host=$(ls "$hosts" 2>/dev/null | head -n1)
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
