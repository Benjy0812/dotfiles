#!/usr/bin/env bash
# dotfiles v1.2: compare this repo with ~/.config and sync the two. Only the
# active profile (profiles/<os>/) is synced; apps/ and mango/ are boilerplate
# that `profile new` copies into a new profile. Run `./dotfiles.bash help`.
set -euo pipefail

VERSION=1.2.0
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$ROOT/dotfiles.bash"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CONFIG/hypr"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$STATE_DIR/backups}" # one folder per file inside
SYNCED="$STATE_DIR/synced.tsv" # "name/file<TAB>sha256" as of the last push or pull
HISTORY="$STATE_DIR/history.tsv" # "run<TAB>kind<TAB>name<TAB>file<TAB>saved copy", for undo
UNDO_DIR="$STATE_DIR/undo"       # repo files as they were before a pull
RUN_SEQ=0
OMARCHY_RESTART=0
DRY=0 JSON=0 COMMIT=0 YES=0
N_COPY=0 N_BACKUP=0 # counted by push/pull/restore for the summary line
PULLED=()           # repo paths written by pulls, for the commit offer

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  B=$'\e[1m' D=$'\e[2m' RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' CYA=$'\e[36m' X=$'\e[0m'
else
  B= D= RED= GRN= YEL= CYA= X=
fi

# Every push, pull or restore is one run, so undo can put back just that run.
new_run() { RUN_ID="$(date +%Y%m%d-%H%M%S)-$((++RUN_SEQ))"; }
new_run

die() { echo "${RED}$*${X}" >&2; exit 1; }
short() { echo "${1/#$HOME/\~}"; }

usage() {
  cat <<EOF
${B}dotfiles${X} v$VERSION: compare this repo with ~/.config and sync the two

${B}Usage${X}
  ./dotfiles.bash [command] [options] [name..]

${B}Everyday${X}
  (no command)  interactive menu: Sync, Backups, Tools (needs gum and fzf)
  status        one row per folder: in sync, edited in ~/.config, newer in repo,
                changed on both sides (--json for scripts)
  diff          show what differs
  push          copy repo files into ~/.config; replaced files are kept in the backup folder
  pull          copy files edited in ~/.config back into the repo (--commit commits them)
  restore       bring a backup back (NAME/FILE for the newest, or pick with fzf)
  skipped       list every file and folder that is not synced, and why
  select        fine-grained: skip single files (see docs/usage.md for folder-level choices)
  undo          put back what the last push, pull or restore changed (--yes to do it)

${B}More${X}
  fetch         list every file that differs, with +/- line counts; changes nothing
  merge NAME FILE  open both copies of a file in nvim -d
  backups       list the backups of tracked files
  clean [DAYS]  list backups older than DAYS (default 30); --yes deletes them
  baseline      record everything that is in sync as the common starting point
  doctor        check tools, .gitignore, backups and links
  watch         notify when a tracked file changes in ~/.config (--auto pulls it)
  setup         hook Omarchy's custom.lua into hyprland.lua, link the settings, install the plugins
  uninstall     undo setup
  profile [NAME|auto|none]  show or choose this machine's profile (the folders that get synced)
  profile set GROUP NAME|all  sync only the chosen app of a group (terminal, editor, shell...)
  profile group GROUP NAME NAME..  define a group of alternatives in profile.conf
  rebuild       NixOS: nixos-rebuild switch for this repo's flake (-n: dry-build)
  edit [NAME[/FILE]]  open the profile (or a folder or file of it) in the preferred editor
  profile new NAME [folder..]  start a profile from the boilerplate in apps/ and mango/
  map           show where each repo folder goes (rules live in .dotfiles-map)
  help, version

${B}Options${X}
  -n, --dry-run   show what would happen, change nothing
  -y, --yes       let clean delete
  --json          status as JSON
  --commit        pull: commit the pulled files (no push)
  -h, --help      same as help
  -v, --version   same as version

${B}Names${X} are folders (\`./dotfiles.bash list\`) or single files (fish/config.fish).
Without names, push and diff use every out-of-sync folder, and pull uses every
folder with edits in ~/.config. NO_COLOR=1 turns colors off.

${B}Files${X} in the profile folder (profiles/<os>/), all optional: profile.conf (preferred
terminal, editor, window manager and shell), .dotfiles-map (where
folders go), .dotfilesignore (paths to skip) and .dotfiles-hosts (which folders belong
on which machine).
EOF
}

# ---- what is managed ------------------------------------------------------

# ---- profiles -------------------------------------------------------------
# Only the active profile is synced: profiles/<name>/<folder>/ goes to
# ~/.config/<folder>/ (omarchy, nixos, ubuntu...). apps/ and mango/ are
# boilerplate; `profile new NAME` copies them into a new profile, which then
# belongs to that OS. Which profile is active: DOTFILES_PROFILE, else the
# choice saved by `profile NAME`, else detected from the machine.
PROFILE_FILE="$STATE_DIR/profile"
PROFILE=

profiles_available() {
  local d
  for d in "$ROOT"/profiles/*/; do [[ -d $d ]] && basename "$d"; done
}

# First profile folder that fits this machine: Omarchy, NixOS, then the distro.
detect_profile() {
  local c id cands=()
  if [[ -d $CONFIG/omarchy ]]; then cands+=(omarchy); fi
  if [[ -e /etc/NIXOS ]]; then cands+=(nixos nix); fi
  if [[ -r /etc/os-release ]]; then id=$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}"); cands+=($id); fi
  for c in "${cands[@]}"; do
    if [[ -d $ROOT/profiles/$c ]]; then echo "$c"; return 0; fi
  done
}

resolve_profile() {
  local want=${DOTFILES_PROFILE:-}
  if [[ -z $want && -f $PROFILE_FILE ]]; then want=$(<"$PROFILE_FILE"); fi
  case ${want:-auto} in
    none) PROFILE= ;;
    auto) PROFILE=$(detect_profile) ;;
    *) PROFILE=$want ;;
  esac
  if [[ -n $PROFILE && ! -d $ROOT/profiles/$PROFILE ]]; then PROFILE=; fi
}

# A profile with a nix/ folder is deployed by home-manager (nixos-rebuild), not
# copied into ~/.config, so dotfiles.bash leaves it alone.
nix_managed() { [[ -n $PROFILE && -d $ROOT/profiles/$PROFILE/nix ]]; }
resolve_profile

# Paths ("folder/file", globs allowed) that are never compared or copied.
ALWAYS_IGNORE=('*/README.md' '*/fish_variables' 'hypr/custom.lua')
USER_IGNORE=() # from the profile's .dotfilesignore, which "Choose what syncs" edits

# matches PATH ("folder/file") against the globs that follow it
matches_any() { # path glob..
  local path=$1 p
  shift
  for p in "$@"; do
    # shellcheck disable=SC2053 # the pattern is meant to be a glob
    [[ $path == $p ]] && return 0
  done
  return 1
}
ignored() { matches_any "$1" "${ALWAYS_IGNORE[@]}" "${USER_IGNORE[@]}"; }

# The settings files live in the profile (profiles/<os>/), never in the repo root.
pfile() { echo "$ROOT/profiles/${PROFILE:-none}/$1"; }

# Preferences: profiles/<os>/profile.conf holds "key = value" lines.
#   group.terminal = alacritty kitty foot ghostty   # defines a group of alternatives
#   terminal = kitty                                # picks one; the rest are not synced
# Groups are defined per profile, so any OS can have its own (group.launcher = rofi wofi).
# A group member that is not chosen stays in the profile folder untouched. "all"
# (or no choice line) syncs every member; a group with no members present is ignored.
declare -A PREF=() PREF_GROUPS=()
PREF_ORDER=()

# Starter groups written into a new profile's profile.conf.
DEFAULT_GROUPS=(
  "terminal=alacritty kitty foot ghostty"
  "editor=nvim zed"
  "wm=hypr mango i3 sway niri bspwm awesome river openbox"
  "shell=fish zsh bash nushell elvish xonsh"
)

# "kitty" -> terminal: the group a folder belongs to, if any.
pref_group_of() {
  local k m
  for k in "${PREF_ORDER[@]}"; do
    for m in ${PREF_GROUPS[$k]}; do [[ $m == "$1" ]] && { echo "$k"; return 0; }; done
  done
  return 1
}

# A folder that belongs to a group whose chosen app is another one is not synced.
not_preferred() { # folder
  local g want
  g=$(pref_group_of "$1") || return 1
  want=${PREF[$g]:-all}
  [[ $want == all || $want == "$1" ]] && return 1
  [[ -d $(pfile "$want") ]] || return 1 # the chosen app is not in this profile
  return 0
}

# Write "key = value" into profile.conf, replacing a line with the same key.
write_conf() { # key value
  local f tmp
  [[ -n $PROFILE ]] || die "no profile is active"
  f=$(pfile profile.conf)
  tmp=$(mktemp)
  if [[ -f $f ]]; then awk -F= -v k="$1" '{ key=$1; gsub(/[[:space:]]/, "", key); if (key != k) print }' "$f" >"$tmp"; fi
  printf '%s = %s\n' "$1" "$2" >>"$tmp"
  mv -f "$tmp" "$f"
  load_profile_settings
  load_entries
}

set_pref() { # group value
  local k=$1 v=$2 m ok=0
  [[ -n ${PREF_GROUPS[$k]:-} ]] || die "unknown group '$k'. Known: ${PREF_ORDER[*]:-none}. Define one: $0 profile group $k NAME NAME.."
  for m in all ${PREF_GROUPS[$k]}; do [[ $m == "$v" ]] && ok=1; done
  ((ok)) || die "$k can be: all ${PREF_GROUPS[$k]}"
  write_conf "$k" "$v"
}

define_group() { # name member..
  local g=$1
  shift
  [[ $g =~ ^[a-z][a-z0-9_-]*$ ]] || die "bad group name '$g' (lowercase letters, digits, - and _)"
  (($# >= 2)) || die "a group needs at least two members: $0 profile group $g NAME NAME.."
  write_conf "group.$g" "$*"
}

# Read the active profile's .dotfilesignore, .dotfiles-map and profile.conf.
# Map rules are "folder/path = target"; the longest match wins; a folder with no
# rule goes to ~/.config/<folder>/.
MAP_SRC=() MAP_DST=()
load_profile_settings() {
  local line src dst i f
  USER_IGNORE=() MAP_SRC=() MAP_DST=()
  PREF=() PREF_GROUPS=() PREF_ORDER=()
  f=$(pfile profile.conf)
  if [[ -f $f ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      line=${line%%#*}
      [[ $line == *=* ]] || continue
      src=${line%%=*} dst=${line#*=}
      src=${src//[[:space:]]/}
      read -ra dst <<<"$dst"
      [[ -n $src && ${#dst[@]} -gt 0 ]] || continue
      if [[ $src == group.* ]]; then
        PREF_GROUPS[${src#group.}]="${dst[*]}"
        PREF_ORDER+=("${src#group.}")
      else
        PREF[$src]=${dst[0]}
      fi
    done <"$f"
  fi
  f=$(pfile .dotfilesignore)
  if [[ -f $f ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      line=${line%%#*}
      line=${line#"${line%%[![:space:]]*}"}
      line=${line%"${line##*[![:space:]]}"}
      [[ -n $line ]] && USER_IGNORE+=("$line")
    done <"$f"
  fi
  f=$(pfile .dotfiles-map)
  if [[ -f $f ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      line=${line%%#*}
      [[ $line == *=* ]] || continue
      src=${line%%=*} dst=${line#*=}
      src=${src#"${src%%[![:space:]]*}"} src=${src%"${src##*[![:space:]]}"}
      dst=${dst#"${dst%%[![:space:]]*}"} dst=${dst%"${dst##*[![:space:]]}"}
      [[ -n $src && -n $dst ]] || continue
      src=${src%/} dst=${dst/#\~/$HOME}
      for i in "${!MAP_SRC[@]}"; do [[ ${MAP_SRC[i]} == "$src" ]] && { MAP_DST[i]=$dst; continue 2; }; done
      MAP_SRC+=("$src") MAP_DST+=("$dst")
    done <"$f"
  fi
}

# Every folder this repo has, one per line.
all_entries() {
  local d
  if [[ -n $PROFILE ]] && ! nix_managed; then
    for d in "$ROOT/profiles/$PROFILE"/*/ "$ROOT/profiles/$PROFILE"/.[!.]*/; do
      [[ -d $d ]] && basename "$d"
    done
  fi
}

# Folders for this machine: all of them, unless the profile's .dotfiles-hosts has a
# "hostname: folder folder" line for it ("*" means all).
ENTRY_LIST=()
load_entries() {
  local host=${DOTFILES_HOST:-$(uname -n)} allowed= e w
  local keep=()
  mapfile -t ENTRY_LIST < <(all_entries | while read -r e; do not_preferred "$e" || echo "$e"; done)
  if [[ -f $(pfile .dotfiles-hosts) ]]; then
    allowed=$(awk -F: -v h="$host" '/^[[:space:]]*#/ {next} $1 == h {print $2}' "$(pfile .dotfiles-hosts)")
  fi
  if [[ -n ${allowed//[[:space:]]/} && $allowed != *'*'* ]]; then
    for e in "${ENTRY_LIST[@]}"; do
      for w in $allowed; do
        if [[ $e == "$w" ]]; then keep+=("$e"); fi
      done
    done
    ENTRY_LIST=("${keep[@]}")
  fi
}
load_profile_settings
load_entries
entries() { if ((${#ENTRY_LIST[@]})); then printf '%s\n' "${ENTRY_LIST[@]}"; fi; }

src_dir() { echo "$ROOT/profiles/${PROFILE:-none}/$1"; }

# Where a repo file lives outside the repo: the longest matching rule of the map.
dest_of() { # name rel
  local key=$1/$2 i best=-1 bi=-1
  for i in "${!MAP_SRC[@]}"; do
    if [[ $key == "${MAP_SRC[i]}" || $key == "${MAP_SRC[i]}"/* ]] && ((${#MAP_SRC[i]} >= best)); then
      best=${#MAP_SRC[i]} bi=$i
    fi
  done
  if ((bi >= 0)); then echo "${MAP_DST[bi]}${key#"${MAP_SRC[bi]}"}"; else echo "$CONFIG/$key"; fi
}

# Files and links of one entry, relative to its folder (NUL separated).
tracked() {
  local rel
  while IFS= read -r -d '' rel; do
    ignored "$1/$rel" || printf '%s\0' "$rel"
  done < <(cd "$(src_dir "$1")" && find . \( -type f -o -type l \) -printf '%P\0')
}

# "NAME" or "NAME/FILE" -> T_NAME and T_REL. Longest folder name wins.
T_NAME= T_REL=
resolve_target() {
  local e
  T_NAME= T_REL=
  while read -r e; do
    if [[ $1 == "$e" ]]; then
      T_NAME=$e T_REL=
      return 0
    elif [[ $1 == "$e"/* ]] && ((${#e} > ${#T_NAME})); then
      T_NAME=$e T_REL=${1#"$e"/}
    fi
  done < <(entries)
  [[ -n $T_NAME ]]
}

# ---- state of each file ---------------------------------------------------

hash_of() { sha256sum -- "$1" | cut -d' ' -f1; }

synced_hash() {
  if [[ -f $SYNCED ]]; then awk -F'\t' -v k="$1" '$1 == k {print $2}' "$SYNCED"; fi
}

# Remember that this file was identical on both sides just now.
record_sync() { # file in ~/.config
  if ((DRY)) || [[ -L $1 || ! -f $1 ]]; then return 0; fi
  mkdir -p "$STATE_DIR"
  local tmp key=${1#"$CONFIG"/}
  tmp=$(mktemp "$STATE_DIR/.synced.XXXXXX")
  {
    if [[ -f $SYNCED ]]; then awk -F'\t' -v k="$key" '$1 != k' "$SYNCED"; fi
    printf '%s\t%s\n' "$key" "$(hash_of "$1")"
  } >"$tmp"
  mv -f "$tmp" "$SYNCED"
}

# Remember one change of the current run so undo can reverse it.
log_change() { # kind name rel [saved]
  if ((DRY)); then return 0; fi
  mkdir -p "$STATE_DIR"
  printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_ID" "$1" "$2" "$3" "${4:-}" >>"$HISTORY"
}

# Keep the repo file as it is before a pull overwrites it.
save_repo_copy() { # name rel src
  local saved=$UNDO_DIR/$RUN_ID/$1/$2
  mkdir -p "$(dirname "$saved")"
  cp -P "$3" "$saved"
  log_change pull "$1" "$2" "$saved"
}

# same | missing | repo-newer | config-newer | conflict, for a repo file and its
# target. With a recorded sync, "conflict" means both sides changed since then;
# without one, the newer modification time decides.
state() {
  local s=$1 d=$2 base
  if [[ ! -e $d && ! -L $d ]]; then echo missing
  elif [[ -L $d && "$(readlink -f "$d")" == "$(readlink -f "$s")" ]]; then echo same
  elif [[ -L $s || -L $d ]]; then
    if [[ "$(readlink "$s" 2>/dev/null)" == "$(readlink "$d" 2>/dev/null)" ]]; then echo same; else echo repo-newer; fi
  elif cmp -s "$s" "$d"; then echo same
  else
    base=$(synced_hash "${d#"$CONFIG"/}")
    if [[ -n $base ]]; then
      if [[ "$(hash_of "$s")" == "$base" ]]; then echo config-newer
      elif [[ "$(hash_of "$d")" == "$base" ]]; then echo repo-newer
      else echo conflict
      fi
    elif [[ $d -nt $s ]]; then echo config-newer
    else echo repo-newer
    fi
  fi
}

# Count the states of one entry into S_same S_repo S_conf S_both S_miss.
tally() {
  S_same=0 S_repo=0 S_conf=0 S_both=0 S_miss=0
  local dir rel
  dir=$(src_dir "$1")
  while IFS= read -r -d '' rel; do
    case "$(state "$dir/$rel" "$(dest_of "$1" "$rel")")" in
      same) ((++S_same)) ;;
      repo-newer) ((++S_repo)) ;;
      config-newer) ((++S_conf)) ;;
      conflict) ((++S_both)) ;;
      missing) ((++S_miss)) ;;
    esac
  done < <(tracked "$1")
}

# "terminal: kitty (alacritty, foot not synced)" lines under the status header.
note_unpreferred() {
  local k e skipped
  for k in "${PREF_ORDER[@]}"; do
    [[ -n ${PREF[$k]:-} && ${PREF[$k]} != all ]] || continue
    skipped=()
    for e in ${PREF_GROUPS[$k]}; do
      if [[ -d $(pfile "$e") ]] && not_preferred "$e"; then skipped+=("$e"); fi
    done
    if ((${#skipped[@]})); then echo "  ${D}$k: ${PREF[$k]} ($(IFS=,; echo "${skipped[*]}" | sed 's/,/, /g') not synced)${X}"; fi
  done
}

# The first glob that matches PATH, or nothing: first_match PATH GLOB..
first_match() {
  local path=$1 p
  shift
  for p in "$@"; do
    # shellcheck disable=SC2053 # the pattern is meant to be a glob
    if [[ $path == $p ]]; then echo "$p"; return 0; fi
  done
  return 1
}

# Everything that is not synced, and why: files skipped by the built-in list or
# by .dotfilesignore, and whole folders left out by a group pick.
skipped_report() {
  local n rel path g m pat total=0 files
  while read -r n; do
    while IFS= read -r -d '' rel; do
      path=$n/$rel
      if pat=$(first_match "$path" "${ALWAYS_IGNORE[@]}"); then
        printf '  %-44s %s\n' "$path" "${D}always skipped ($pat)${X}"
      elif pat=$(first_match "$path" "${USER_IGNORE[@]}"); then
        printf '  %-44s %s\n' "$path" "${YEL}.dotfilesignore${X} ${D}($pat)${X}"
      else
        continue
      fi
      ((++total))
    done < <(cd "$(src_dir "$n")" && find . \( -type f -o -type l \) -printf '%P\0' | sort -z)
  done < <(entries)
  for g in "${PREF_ORDER[@]}"; do
    [[ -n ${PREF[$g]:-} && ${PREF[$g]} != all ]] || continue
    for m in ${PREF_GROUPS[$g]}; do
      [[ -d $(pfile "$m") ]] && not_preferred "$m" || continue
      files=$(find "$(pfile "$m")" \( -type f -o -type l \) | wc -l)
      printf '  %-44s %s\n' "$m/ ($files files)" "${CYA}not picked${X} ${D}($g = ${PREF[$g]}; change: $0 profile set $g NAME)${X}"
      ((++total))
    done
  done
  if ((total == 0)); then echo "  nothing is skipped"; else echo; echo "  ${D}Change it: Tools > Profile settings (folders), Choose what syncs (files), or edit $(short "$(pfile .dotfilesignore)")${X}"; fi
}

# How many files of one folder .dotfilesignore (or the built-in list) skips.
skipped_count() {
  local rel n=0
  while IFS= read -r -d '' rel; do
    if ignored "$1/$rel"; then ((++n)); fi
  done < <(cd "$(src_dir "$1")" && find . \( -type f -o -type l \) -printf '%P\0')
  echo "$n"
}

# ---- omarchy --------------------------------------------------------------
# The Omarchy folder is synced like the others. `setup` adds what copying
# cannot: the hyprland.lua hook, the settings links and the plugin hooks.

# Settings files in the profile's hypr/ (not custom.lua): linked into ~/.config/hypr/.
omarchy_settings() {
  local f
  for f in "$(src_dir hypr)"/*.lua; do
    [[ -f $f && $(basename "$f") != custom.lua ]] && basename "$f"
  done
}

# Plugin ids: every folder in omarchy/plugins/.
omarchy_plugins() {
  local d
  for d in "$(src_dir omarchy)"/plugins/*/; do [[ -d $d ]] && basename "$d"; done
}

# A plugin with a bar widget hooks into bindings.lua, the others into autostart.lua.
plugin_hook_file() {
  if [[ -f $(src_dir omarchy)/plugins/$1/Widget.qml ]]; then echo "$HYPR/bindings.lua"; else echo "$HYPR/autostart.lua"; fi
}

# installed | partial | missing, for the hyprland.lua hook and the settings links.
omarchy_state() {
  local ok=0 total=1 f
  if grep -qsF "$(src_dir hypr)/custom.lua" "$HYPR/hyprland.lua"; then ((++ok)); fi
  while read -r f; do
    ((++total))
    if [[ "$(readlink "$HYPR/$f" 2>/dev/null)" == "$(src_dir hypr)/$f" ]]; then ((++ok)); fi
  done < <(omarchy_settings)
  if ((ok == total)); then echo installed; elif ((ok > 0)); then echo partial; else echo missing; fi
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
  local id=$1 hook dest=$CONFIG/omarchy/plugins/$1 shell=$CONFIG/omarchy/shell.json rel
  hook=$(plugin_hook_file "$id")
  [[ -f $hook ]] || die "missing $(short "$hook")"
  cp "$hook" "$hook.bak"
  remove_hook "$hook" "$id"
  while IFS= read -r -d '' rel; do
    [[ $rel == plugins/$id/* ]] && push_file omarchy "$rel"
  done < <(tracked omarchy)
  printf '%s\n' "-- >>> $id >>>" "dofile(\"$dest/${id#*.}.lua\")" "-- <<< $id <<<" >>"$hook"
  echo "  ${GRN}plugin${X}  $id"
  # A plugin with a widget replaces Omarchy's global workspace strip in the bar.
  if [[ -f $(src_dir omarchy)/plugins/$id/Widget.qml && -f $shell ]] && grep -q '"omarchy.workspaces"' "$shell"; then
    cp "$shell" "$shell.bak"
    sed -i "s/\"omarchy.workspaces\"/\"$id\"/" "$shell"
    OMARCHY_RESTART=1
  fi
}

plugin_uninstall() { # id
  local id=$1 shell=$CONFIG/omarchy/shell.json
  remove_hook "$(plugin_hook_file "$id")" "$id"
  rm -rf "$CONFIG/omarchy/plugins/$id"
  if [[ -f $(src_dir omarchy)/plugins/$id/Widget.qml && -f $shell ]]; then
    sed -i "s/\"$id\"/\"omarchy.workspaces\"/" "$shell"
    OMARCHY_RESTART=1
  fi
  echo "  ${YEL}removed${X} plugin $id"
}

omarchy_reload() {
  hyprctl reload >/dev/null 2>&1 && hyprctl configerrors || true
  # Plugin hot-reload can keep the old widget cached, so restart the bar.
  if ((OMARCHY_RESTART)); then omarchy restart shell >/dev/null 2>&1 || true; fi
}

# True when the active profile carries the Omarchy files.
omarchy_ready() { [[ -f $(src_dir hypr)/custom.lua && -d $(src_dir omarchy)/plugins ]]; }

# Load custom.lua from hyprland.lua, link the settings, install the plugins.
# Safe to run again, e.g. after `omarchy refresh hyprland`.
omarchy_setup() {
  local hl=$HYPR/hyprland.lua f
  if ((DRY)); then echo "would hook custom.lua into hyprland.lua, link the settings and install the plugins"; return 0; fi
  [[ -f $hl ]] || die "missing $(short "$hl")"
  omarchy_ready || die "the profile '${PROFILE:-none}' has no hypr/custom.lua and omarchy/plugins/"
  OMARCHY_RESTART=0
  cp "$hl" "$hl.bak"
  # Skip Omarchy's preinstalled app binds; has to be set before its defaults load.
  sed -i 's/^-- *omarchy_preinstalled_bindings = false/omarchy_preinstalled_bindings = false/' "$hl"
  sed -i '/omarchy\/hypr\/custom.lua/d' "$hl"
  echo "dofile(\"$(src_dir hypr)/custom.lua\")" >>"$hl"
  echo "  ${GRN}hook${X}    custom.lua loads from hyprland.lua"
  # Link before the plugin hooks run, so the plugins don't create default settings.
  while read -r f; do
    if [[ -e $HYPR/$f && ! -L $HYPR/$f ]]; then stash omarchy "hypr/$f" "$HYPR/$f"; fi
    ln -sfn "$(src_dir hypr)/$f" "$HYPR/$f"
    echo "  ${GRN}link${X}    hypr/$f"
  done < <(omarchy_settings)
  while read -r f; do plugin_install "$f"; done < <(omarchy_plugins)
  omarchy_reload
}

omarchy_uninstall() {
  local hl=$HYPR/hyprland.lua f
  if ((DRY)); then echo "would remove the hook, the settings links and the plugins"; return 0; fi
  OMARCHY_RESTART=0
  while read -r f; do plugin_uninstall "$f"; done < <(omarchy_plugins)
  # Only remove links pointing here; the settings stay in this repo.
  while read -r f; do
    if [[ "$(readlink "$HYPR/$f" 2>/dev/null)" == "$(src_dir hypr)/$f" ]]; then rm "$HYPR/$f"; fi
  done < <(omarchy_settings)
  if [[ -f $hl ]]; then
    cp "$hl" "$hl.bak"
    sed -i '/omarchy\/hypr\/custom.lua/d' "$hl"
    sed -i 's/^omarchy_preinstalled_bindings = false/-- omarchy_preinstalled_bindings = false/' "$hl"
  fi
  omarchy_reload
  echo "${B}removed${X} the Omarchy hook, links and plugins"
}

# Names that need a push / have edits in ~/.config.
out_of_sync() {
  local n
  while read -r n; do
    tally "$n"
    if ((S_repo + S_conf + S_both + S_miss > 0)); then echo "$n"; fi
  done < <(entries)
}
config_edited() {
  local n
  while read -r n; do
    tally "$n"
    if ((S_conf + S_both > 0)); then echo "$n"; fi
  done < <(entries)
}

# ---- status ---------------------------------------------------------------

# "branch ●N" for the repo: N is the number of uncommitted paths.
repo_state() {
  local branch dirty
  branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null) || return 0
  dirty=$(git -C "$ROOT" status --porcelain | wc -l)
  if ((dirty > 0)); then echo "$branch ${YEL}●$dirty${X}"; else echo "$branch ${GRN}clean${X}"; fi
}

show_status() {
  local n label parts p skip note
  printf '\n  %sdotfiles%s %sv%s%s  %s%s → %s%s  %s\n\n' "$B$CYA" "$X" "$D" "$VERSION" "$X" \
    "$D" "$(short "$ROOT")" "$(short "$CONFIG")" "$X" "$(repo_state)${PROFILE:+  ${D}profile $PROFILE${X}}"
  note_unpreferred
  if nix_managed; then echo "  ${CYA}Profile $PROFILE is managed by Nix${X} ${D}(nixos-rebuild deploys it; nothing to sync)${X}"; fi
  while read -r n; do
    tally "$n"
    parts=()
    if ((S_both)); then parts+=("${RED}⚠ $S_both changed on both sides${X}"); fi
    if ((S_conf)); then parts+=("${YEL}✎ $S_conf edited in ~/.config${X}"); fi
    if ((S_repo)); then parts+=("${CYA}↑ $S_repo newer in repo${X}"); fi
    if ((S_miss)); then parts+=("${RED}✗ $S_miss not installed${X}"); fi
    skip=$(skipped_count "$n")
    note=
    if ((skip)); then note=", $skip skipped"; fi
    if ((S_same == 0 && ${#parts[@]} == 0 && skip)); then
      label="${D}– all $skip files skipped${X}"
    elif ((${#parts[@]} == 0)); then
      label="${GRN}✔ in sync${X} ${D}($S_same files$note)${X}"
    else
      label=${parts[0]}
      for p in "${parts[@]:1}"; do label+=" ${D}·${X} $p"; done
    fi
    if [[ $n == omarchy ]] && omarchy_ready && [[ $(omarchy_state) != installed ]]; then
      label+=" ${D}·${X} ${YEL}hook $(omarchy_state)${X} ${D}(Tools)${X}"
    fi
    printf '  %-14s %s\n' "$n" "$label"
  done < <(entries)
  printf '\n'
  hint_skipped
}

# "12 skipped: ./dotfiles.bash skipped" under the status table, when something is.
hint_skipped() {
  local n total=0 g m
  while read -r n; do total=$((total + $(skipped_count "$n"))); done < <(entries)
  for g in "${PREF_ORDER[@]}"; do
    [[ -n ${PREF[$g]:-} && ${PREF[$g]} != all ]] || continue
    for m in ${PREF_GROUPS[$g]}; do [[ -d $(pfile "$m") ]] && not_preferred "$m" && ((++total)); done
  done
  if ((total)); then echo "  ${D}Some files and folders are skipped. See what and why: $0 skipped${X}"; echo; fi
}

status_json() {
  local n first=1
  printf '['
  while read -r n; do
    ((first)) || printf ','
    first=0
    tally "$n"
    printf '{"name":"%s","in_sync":%d,"edited_in_config":%d,"newer_in_repo":%d,"conflict":%d,"not_installed":%d}' \
      "$n" "$S_same" "$S_conf" "$S_repo" "$S_both" "$S_miss"
  done < <(entries)
  printf ']\n'
}

# State -> colored label.
tag_for() {
  case $1 in
    config-newer) echo "${YEL}✎ edited in ~/.config${X}" ;;
    repo-newer) echo "${CYA}↑ newer in repo${X}" ;;
    conflict) echo "${RED}⚠ changed on both sides${X}" ;;
    *) echo "${RED}✗ not installed${X}" ;;
  esac
}

# Tab-separated "name rel state" for every file that differs. Mode "pull"
# leaves out files missing from ~/.config, since there is nothing to pull.
changed_files() { # all | pull
  local n rel st dir
  while read -r n; do
    dir=$(src_dir "$n")
    while IFS= read -r -d '' rel; do
      st=$(state "$dir/$rel" "$(dest_of "$n" "$rel")")
      [[ $st == same ]] && continue
      [[ $1 == pull && $st == missing ]] && continue
      printf '%s\t%s\t%s\n' "$n" "$rel" "$st"
    done < <(tracked "$n")
  done < <(entries)
}

# " +N -M": lines of file $2 that are new / missing compared with file $1.
diff_stat() {
  local add del
  if [[ -L $1 || -L $2 ]]; then return 0; fi
  add=$(diff "$1" "$2" | grep -c '^>' || true)
  del=$(diff "$1" "$2" | grep -c '^<' || true)
  printf ' %s+%s%s %s-%s%s' "$GRN" "$add" "$X" "$RED" "$del" "$X"
}

# Read-only preview of every differing file; +/- count lines of the
# ~/.config copy against the repo copy.
fetch_report() {
  local n rel st src dest stat total=0
  while IFS=$'\t' read -r n rel st; do
    src=$(src_dir "$n")/$rel dest=$(dest_of "$n" "$rel")
    stat=
    if [[ $st != missing ]]; then stat=$(diff_stat "$src" "$dest"); fi
    printf '  %-38s %s%s\n' "$n/$rel" "$(tag_for "$st")" "$stat"
    ((++total))
  done < <(changed_files all)
  if ((total == 0)); then echo "  ${GRN}everything in sync${X}"; else echo; echo "  $total file(s) differ"; fi
}

# ---- copying --------------------------------------------------------------

# An unused backup path: $BACKUP_DIR/<folder>/<file>/<timestamp>, so every file
# gets its own folder of backups (default ~/.local/state/dotfiles/backups).
backup_path() { # name rel
  local dir=$BACKUP_DIR/$1/$2 b i=1
  b=$dir/$(date +%Y%m%d-%H%M%S)
  while [[ -e $b || -L $b ]]; do b=$dir/$(date +%Y%m%d-%H%M%S).$i; ((++i)); done
  echo "$b"
}

# Move a file into its backup folder. The backup's age counts from now, not
# from when the file was last edited.
stash() { # name rel file
  local bak
  bak=$(backup_path "$1" "$2")
  echo "  ${YEL}backup${X}  $(short "$bak")"
  ((++N_BACKUP))
  if ((!DRY)); then
    mkdir -p "$(dirname "$bak")"
    mv -T "$3" "$bak"
    touch -h "$bak"
    log_change stash "$1" "$2" "$bak"
  fi
}

# One file, repo -> ~/.config; a different old file is kept as a backup.
push_file() { # name rel
  local src dest st
  src=$(src_dir "$1")/$2 dest=$(dest_of "$1" "$2")
  if [[ ! -e $src && ! -L $src ]]; then echo "  ${RED}not in the repo${X}  $1/$2"; return 0; fi
  st=$(state "$src" "$dest")
  [[ $st == same ]] && return 0
  if [[ $st != missing ]]; then stash "$1" "$2" "$dest"; fi
  echo "  ${GRN}copy${X}    $(short "$dest")"
  ((++N_COPY))
  if ((!DRY)); then
    mkdir -p "$(dirname "$dest")"
    cp -P "$src" "$dest"
    if [[ $st == missing ]]; then log_change created "$1" "$2"; fi
    record_sync "$dest"
  fi
}

# One file, ~/.config -> repo. Git is the undo, so no backup.
pull_file() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$(dest_of "$1" "$2")
  if [[ ! -e $src && ! -L $src ]]; then echo "  ${RED}not tracked in the repo${X}  $1/$2"; return 0; fi
  if [[ ! -e $dest && ! -L $dest ]]; then echo "  ${RED}not in ~/.config${X}  $1/$2"; return 0; fi
  [[ "$(state "$src" "$dest")" == same ]] && return 0
  echo "  ${YEL}pull${X}    $1/$2"
  ((++N_COPY))
  if ((!DRY)); then
    save_repo_copy "$1" "$2" "$src"
    cp -P "$dest" "$src"
    PULLED+=("${src#"$ROOT"/}")
    record_sync "$dest"
  fi
}

install_entry() {
  local name=$1 rel
  echo "${B}$name${X}"
  while IFS= read -r -d '' rel; do push_file "$name" "$rel"; done < <(tracked "$name")
}

# Every file edited in ~/.config and not changed in the repo since.
pull_entry() {
  local name=$1 rel
  echo "${B}$name${X}"
  while IFS= read -r -d '' rel; do
    case "$(state "$(src_dir "$name")/$rel" "$(dest_of "$name" "$rel")")" in
      config-newer) pull_file "$name" "$rel" ;;
      conflict) echo "  ${RED}⚠ skipped${X}  $name/$rel changed on both sides (use merge, or pull the file by name)" ;;
    esac
  done < <(tracked "$name")
}

# Colored diff of one file: - is the repo copy, + is the ~/.config copy.
file_diff() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$(dest_of "$1" "$2")
  case "$(state "$src" "$dest")" in
    same) ;;
    missing) echo "${RED}not installed${X}  $1/$2" ;;
    *)
      if [[ -L $src || -L $dest ]]; then
        echo "${YEL}link differs${X}  $1/$2"
      else
        diff --color=always -u --label "repo/$1/$2" --label "config/$1/$2" "$src" "$dest" || true
      fi
      ;;
  esac
}

diff_entry() {
  local name=$1 rel
  while IFS= read -r -d '' rel; do file_diff "$name" "$rel"; done < <(tracked "$name")
}

# Both copies side by side in nvim (left: repo, right: ~/.config); save the
# merged result into whichever side you want to keep, then push or pull it.
merge_file() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$(dest_of "$1" "$2")
  [[ -f $src && -f $dest ]] || die "both copies must exist: $1/$2"
  if command -v nvim >/dev/null; then nvim -d "$src" "$dest"; else vimdiff "$src" "$dest"; fi
}

summary() { # VERB
  local did=$1 note=
  if ((DRY)); then note=" ${D}(dry run, nothing changed)${X}"; fi
  if ((N_COPY + N_BACKUP == 0)); then
    echo "${GRN}nothing to do${X}"
  else
    echo "${B}$did:${X} $N_COPY file(s), $N_BACKUP backup(s)$note"
  fi
}

# ---- commit after a pull --------------------------------------------------

commit_message() {
  local names
  names=$(printf '%s\n' "${PULLED[@]}" | awk -F/ '{print ($1 == "apps") ? $2 : ($1 == "profiles") ? $3 : $1}' | sort -u | paste -sd, | sed 's/,/, /g')
  echo "sync config from ~/.config: $names"
}

commit_pulled() { # message
  git -C "$ROOT" add -- "${PULLED[@]}"
  git -C "$ROOT" commit -q -m "$1" -- "${PULLED[@]}"
  echo "${GRN}committed${X} ${#PULLED[@]} file(s): $1"
  PULLED=()
}

offer_commit() {
  ((${#PULLED[@]})) || return 0
  local choice msg
  echo
  git -C "$ROOT" diff --stat --color=always -- "${PULLED[@]}" || true
  choice=$(choose "Commit the pulled files?" \
    "Commit|Commit the pulled files with the message you edit next." \
    "Commit and push|Commit, then ask before pushing to origin." \
    "Skip|Leave the files uncommitted; they show in git status.") || return 0
  [[ $choice == Skip ]] && return 0
  msg=$(gum input --width 72 --value "$(commit_message)") || return 0
  [[ -n $msg ]] || return 0
  commit_pulled "$msg"
  if [[ $choice == "Commit and push" ]] && gum confirm "Push to origin?"; then
    git -C "$ROOT" push
  fi
}

# ---- backups --------------------------------------------------------------

# Tab-separated "name rel backup" for every backup of a tracked file.
backups() {
  local n rel dest b
  while read -r n; do
    while IFS= read -r -d '' rel; do
      dest=$(dest_of "$n" "$rel")
      # Per-file backup folder, plus .bak files left next to the file by older versions.
      for b in "$BACKUP_DIR/$n/$rel"/* "$dest".bak*; do
        if [[ -f $b || -L $b ]]; then printf '%s\t%s\t%s\n' "$n" "$rel" "$b"; fi
      done
    done < <(tracked "$n")
  done < <(entries)
}

latest_backup() { # name rel
  ls -t -- "$BACKUP_DIR/$1/$2"/* "$(dest_of "$1" "$2")".bak* 2>/dev/null | head -n1 || true
}

# Bring a backup back. The current file is backed up first, so nothing is lost.
restore_backup() { # name rel backup
  local dest=$(dest_of "$1" "$2")
  if [[ -e $dest || -L $dest ]]; then stash "$1" "$2" "$dest"; fi
  echo "  ${GRN}restore${X} $(short "$dest")  ${D}from $(basename "$3")${X}"
  ((++N_COPY))
  if ((!DRY)); then
    mkdir -p "$(dirname "$dest")"
    cp -P "$3" "$dest"
  fi
}

restore_entry() { echo "  ${RED}restore takes NAME/FILE${X}  $1"; }

restore_target() { # name rel
  local b
  b=$(latest_backup "$1" "$2")
  [[ -n $b ]] || { echo "  ${RED}no backup${X}  $1/$2"; return 0; }
  restore_backup "$1" "$2" "$b"
}

# ---- undo -----------------------------------------------------------------

# "2026-10-30 14:02" from a run id like 20261030-140212-1.
run_time() {
  local id=${1%-*}
  date -d "${id:0:8} ${id:9:2}:${id:11:2}:${id:13:2}" '+%F %H:%M' 2>/dev/null || echo "$id"
}

# Newest run in the history, and its changes newest first.
last_run() { if [[ -s $HISTORY ]]; then tail -n1 "$HISTORY" | cut -f1; fi; }
run_changes() { awk -F'\t' -v r="$1" '$1 == r' "$HISTORY" | tac; }

# Put back everything the newest run changed: replaced ~/.config files, new
# files (moved to the backups) and repo files that a pull overwrote. Undoing is
# itself a run, so undoing again redoes it.
undo_last() { # [confirm]
  local run lines=() line kind n rel saved dest src
  run=$(last_run)
  if [[ -z $run ]]; then echo "nothing to undo"; return 0; fi
  mapfile -t lines < <(run_changes "$run")
  echo "${B}Last sync${X}  $(run_time "$run")"
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r _ kind n rel saved <<<"$line"
    case $kind in
      stash) echo "  ${CYA}←${X} put back the old ~/.config copy of $n/$rel" ;;
      created) echo "  ${RED}×${X} remove $n/$rel from ~/.config (it was new; kept as a backup)" ;;
      pull) echo "  ${CYA}←${X} put back the old repo copy of $n/$rel" ;;
    esac
  done
  if [[ ${1:-} == confirm ]]; then
    gum confirm --affirmative Undo --negative Cancel "Undo these ${#lines[@]} change(s)?" || return 0
  elif ((!YES && !DRY)); then
    echo "Pass --yes to undo."
    return 0
  fi
  new_run
  N_COPY=0 N_BACKUP=0
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r _ kind n rel saved <<<"$line"
    dest=$(dest_of "$n" "$rel") src=$(src_dir "$n")/$rel
    case $kind in
      stash)
        if [[ -e $saved || -L $saved ]]; then restore_backup "$n" "$rel" "$saved"
        else echo "  ${RED}backup is gone${X}  $n/$rel"; fi
        ;;
      created)
        if [[ -e $dest || -L $dest ]]; then stash "$n" "$rel" "$dest"; fi
        ;;
      pull)
        if [[ -e $saved ]]; then
          echo "  ${GRN}restore${X} $n/$rel in the repo"
          ((++N_COPY))
          if ((!DRY)); then save_repo_copy "$n" "$rel" "$src"; cp -P "$saved" "$src"; fi
        else echo "  ${RED}old repo copy is gone${X}  $n/$rel"; fi
        ;;
    esac
  done
  summary undone
}

# Backups older than DAYS: listed, and deleted with --yes (or after confirming).
clean_backups() { # days [confirm]
  local days=$1 n rel b old=()
  while IFS=$'\t' read -r n rel b; do
    if [[ -n $(find "$b" -maxdepth 0 -mtime +"$days") ]]; then old+=("$b"); fi
  done < <(backups)
  if ((${#old[@]} == 0)); then echo "${GRN}no backups older than $days days${X}"; return 0; fi
  printf '  %s\n' "${old[@]/#$HOME/\~}"
  if ((DRY)) || { ((!YES)) && [[ ${2:-} != confirm ]]; }; then
    echo "${#old[@]} backup(s) older than $days days. Pass --yes to delete them."
    return 0
  fi
  if [[ ${2:-} == confirm ]] && ! gum confirm "Delete ${#old[@]} backup(s)?"; then return 0; fi
  rm -- "${old[@]}"
  find "$BACKUP_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  echo "${B}deleted${X} ${#old[@]} backup(s)"
}

# Record every file that is identical right now as the common starting point.
baseline() {
  local n rel dir count=0
  while read -r n; do
    dir=$(src_dir "$n")
    while IFS= read -r -d '' rel; do
      if [[ "$(state "$dir/$rel" "$(dest_of "$n" "$rel")")" == same ]]; then
        record_sync "$(dest_of "$n" "$rel")"
        ((++count))
      fi
    done < <(tracked "$n")
  done < <(entries)
  echo "recorded $count file(s) as in sync ${D}($(short "$SYNCED"))${X}"
}

# ---- doctor and watch -----------------------------------------------------

d_ok() { echo "  ${GRN}✔${X} $*"; }
d_warn() { echo "  ${YEL}!${X} $*"; }
d_bad() { echo "  ${RED}✗${X} $*"; DOCTOR_BAD=1; }

doctor() {
  DOCTOR_BAD=0
  local c n rel path old=0 b
  echo "${B}tools${X}"
  for c in git gum fzf; do
    if command -v "$c" >/dev/null; then d_ok "$c"; else d_bad "$c is missing (the menu needs it)"; fi
  done
  if command -v wl-copy >/dev/null || command -v xclip >/dev/null; then d_ok "clipboard tool"; else d_warn "wl-copy or xclip is missing (nvim's system clipboard)"; fi
  for c in inotifywait notify-send nvim; do
    if command -v "$c" >/dev/null; then d_ok "$c"; else d_warn "$c is missing (watch / merge)"; fi
  done

  echo "${B}repo${X}"
  if git -C "$ROOT" rev-parse >/dev/null 2>&1; then d_ok "git repository ($(repo_state))"; else d_bad "not a git repository"; fi
  while read -r n; do
    while IFS= read -r -d '' rel; do
      path=$(src_dir "$n")/$rel
      if git -C "$ROOT" check-ignore -q -- "$path"; then d_bad "$n/$rel is ignored by .gitignore, so git will not track it"; fi
    done < <(tracked "$n")
  done < <(entries)
  d_ok "tracked files checked against .gitignore"

  echo "${B}~/.config${X}"
  while read -r n; do
    [[ $n == omarchy ]] && continue
    if [[ -d $CONFIG/$n ]]; then
      while IFS= read -r path; do d_warn "broken link: $(short "$path")"; done < <(find "$CONFIG/$n" -xtype l)
    fi
  done < <(entries)
  while IFS=$'\t' read -r n rel b; do
    if [[ -n $(find "$b" -maxdepth 0 -mtime +30) ]]; then ((++old)); fi
  done < <(backups)
  if ((old)); then d_warn "$old backup(s) older than 30 days (clean)"; else d_ok "no old backups"; fi

  echo "${B}state${X}"
  d_ok "profile: ${PROFILE:-none}"
  if [[ -f $SYNCED ]]; then d_ok "$(wc -l <"$SYNCED") file(s) recorded in $(short "$SYNCED")"; else d_warn "no sync record yet (run baseline for exact conflict detection)"; fi
  d_ok "machine $(uname -n): $(entries | paste -sd' ')"
  return "$DOCTOR_BAD"
}

# Notify (or with --auto, pull) when a tracked file is saved in ~/.config.
watch_config() { # [--auto] [name..]
  command -v inotifywait >/dev/null || die "watch needs inotify-tools (sudo pacman -S inotify-tools)"
  local auto=0 want=() dirs=() n t key src dest st now
  declare -A seen=()
  for t in "$@"; do
    if [[ $t == --auto ]]; then auto=1; else want+=("$t"); fi
  done
  if ((${#want[@]} == 0)); then mapfile -t want < <(entries); fi
  for n in "${want[@]}"; do
    [[ $n == omarchy ]] && continue
    resolve_target "$n" && [[ -z $T_REL ]] || die "watch takes folder names: $n"
    [[ -d $CONFIG/$n ]] && dirs+=("$CONFIG/$n")
  done
  ((${#dirs[@]})) || die "nothing to watch in $(short "$CONFIG")"
  echo "watching ${#dirs[@]} folder(s) in $(short "$CONFIG")$( ((auto)) && echo ', auto-pulling edits')  ${D}(ctrl-c stops)${X}"
  while IFS= read -r path; do
    key=${path#"$CONFIG"/}
    now=$(date +%s)
    if ((now - ${seen[$key]:-0} < 1)); then continue; fi
    seen[$key]=$now
    resolve_target "$key" && [[ -n $T_REL ]] || continue
    ignored "$key" && continue
    src=$(src_dir "$T_NAME")/$T_REL dest=$path
    [[ -e $src ]] || continue
    st=$(state "$src" "$dest")
    case $st in
      config-newer)
        if ((auto)); then
          pull_file "$T_NAME" "$T_REL"
        else
          echo "$(date +%T)  ${YEL}edited${X}  $key"
          command -v notify-send >/dev/null && notify-send "dotfiles" "$key edited in ~/.config. Run: dotfiles.bash pull $key" || true
        fi
        ;;
      conflict)
        echo "$(date +%T)  ${RED}changed on both sides${X}  $key"
        command -v notify-send >/dev/null && notify-send -u critical "dotfiles" "$key changed on both sides. Run: dotfiles.bash merge $key" || true
        ;;
    esac
  done < <(inotifywait -m -r -q -e close_write,moved_to --format '%w%f' "${dirs[@]}")
}

# ---- menu -----------------------------------------------------------------

pause() { read -rp $'\n  enter to continue… ' _ || true; }

MSG= KEEP=0 # a line shown under the status table, and whether to skip the next clear

# choose HEADER "label|description".. -> the chosen label. With fzf the
# description of the highlighted item shows under the list; without it this is
# a plain gum choose.
choose() {
  local header=$1 item labels=()
  shift
  if command -v fzf >/dev/null; then
    for item in "$@"; do printf '%s\t%s\n' "${item%%|*}" "${item#*|}"; done |
      fzf --layout=reverse --height=$(($# + 8)) --border=rounded --no-info --no-scrollbar \
        --delimiter=$'\t' --with-nth=1 --header "$header" --prompt "" --pointer ">" --gutter ' ' \
        --preview 'printf "%s\n" {2}' --preview-window 'down,2,wrap,border-top' |
      cut -f1
  else
    for item in "$@"; do labels+=("${item%%|*}"); done
    gum choose --header "$header" --cursor "> " "${labels[@]}"
  fi
}

need_fzf() {
  command -v fzf >/dev/null && return 0
  echo "  the file picker needs fzf (sudo pacman -S fzf)"
  pause
  return 1
}

# Colored "what Enter will do" label for one differing file.
sync_tag() {
  case $1 in
    config-newer) echo "${YEL}← save to repo${X}      edited in ~/.config" ;;
    repo-newer) echo "${CYA}→ save to ~/.config${X}  newer in repo" ;;
    conflict) echo "${RED}⚠ both changed${X}       you choose" ;;
    *) echo "${CYA}→ save to ~/.config${X}  not installed" ;;
  esac
}

# One line under the status table saying what to do next. Sets PENDING.
next_step() {
  local st e=0 r=0 b=0 m=0 parts=() list p
  while IFS=$'\t' read -r _ _ st; do
    case $st in
      config-newer) ((++e)) ;;
      repo-newer) ((++r)) ;;
      conflict) ((++b)) ;;
      missing) ((++m)) ;;
    esac
  done <<<"$DIFFS"
  if nix_managed; then
    PENDING=0
    echo "  ${CYA}Profile $PROFILE is managed by Nix.${X} Edit it in the repo, then Tools > NixOS: rebuild (or ./dotfiles.bash rebuild)."
    return 0
  fi
  if [[ -z $PROFILE ]]; then
    PENDING=0
    echo "  ${YEL}No profile for this machine.${X} Open Tools > Profile to pick one or start one from the boilerplate."
    return 0
  fi
  PENDING=$((e + r + b + m))
  if ((PENDING == 0)); then echo "  ${GRN}Everything is in sync.${X}"; return 0; fi
  if ((e)); then parts+=("$e edited in ~/.config"); fi
  if ((r)); then parts+=("$r newer in repo"); fi
  if ((b)); then parts+=("$b changed on both sides"); fi
  if ((m)); then parts+=("$m not installed"); fi
  list=${parts[0]}
  for p in "${parts[@]:1}"; do list+=", $p"; done
  echo "  ${B}Next:${X} open Sync to review $PENDING file(s): $list"
}

# The list of changes the user is about to approve.
sync_review() { # plan lines: act<TAB>name<TAB>rel
  local p act n rel src dest
  clear
  printf '\n  %sReview%s\n\n' "$B$CYA" "$X"
  for p in "$@"; do
    IFS=$'\t' read -r act n rel <<<"$p"
    src=$(src_dir "$n")/$rel dest=$(dest_of "$n" "$rel")
    if [[ $act == push ]]; then
      if [[ -e $dest || -L $dest ]]; then
        printf '  → ~/.config  %-34s%s  replaces it, old copy kept as a backup\n' "$n/$rel" "$(diff_stat "$dest" "$src")"
      else
        printf '  → ~/.config  %-34s  new file\n' "$n/$rel"
      fi
    else
      printf '  ← repo       %-34s%s  replaces the repo file, git can undo it\n' "$n/$rel" "$(diff_stat "$src" "$dest")"
    fi
  done
  echo
}

# Every file that differs in one fzf list. Files that are safe to apply start
# ticked, so Enter is the usual answer; files changed on both sides start
# unticked and ask first. Keys: tab toggles, ctrl-a all, ctrl-d none, ctrl-e nvim -d.
menu_sync() {
  need_fzf || return 0
  local n rel st line safe=() conf=() rows picked row act choice plan=() preselect i p
  while IFS=$'\t' read -r n rel st; do
    line=$(printf '%-38s %s\t%s\t%s\t%s' "$n/$rel" "$(sync_tag "$st")" "$n" "$rel" "$st")
    if [[ $st == conflict ]]; then conf+=("$line"); else safe+=("$line"); fi
  done < <(changed_files all)
  if ((${#safe[@]} + ${#conf[@]} == 0)); then MSG="${GRN}everything is in sync${X}"; return 0; fi
  rows=$(printf '%s\n' "${safe[@]}" "${conf[@]}" | sed '/^$/d')
  preselect="load:select-all"
  for ((i = 1; i <= ${#conf[@]}; i++)); do preselect+="+pos(-$i)+deselect"; done
  preselect+="+pos(1)"
  mapfile -t picked < <(fzf --multi --ansi --layout=reverse --height=90% --delimiter=$'\t' --with-nth=1 \
    --prompt "sync > " --pointer ">" --marker "+" \
    --header $'ticked files are applied on enter · tab toggles · ctrl-a all · ctrl-d none · ctrl-e merge\ndiff: - repo, + ~/.config' \
    --preview "'$SELF' preview {2} {3}" \
    --preview-window 'down,60%,wrap,border-top' \
    --bind "$preselect" \
    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
    --bind "ctrl-e:execute('$SELF' merge {2} {3})" <<<"$rows" || true)
  ((${#picked[@]})) || return 0
  for row in "${picked[@]}"; do
    IFS=$'\t' read -r _ n rel st <<<"$row"
    case $st in
      config-newer) act=pull ;;
      conflict)
        choice=$(choose "$n/$rel changed on both sides" \
          "Keep the repo copy|Replaces the ~/.config file; the old one is kept as a backup." \
          "Keep the ~/.config copy|Replaces the repo file (git can undo it)." \
          "Merge in nvim|Open both copies side by side. Nothing is applied now." \
          "Skip|Leave both as they are.") || choice=Skip
        case $choice in
          "Keep the repo copy") act=push ;;
          "Keep the ~/.config copy") act=pull ;;
          "Merge in nvim") merge_file "$n" "$rel"; act=skip ;;
          *) act=skip ;;
        esac
        ;;
      *) act=push ;;
    esac
    if [[ $act != skip ]]; then plan+=("$act"$'\t'"$n"$'\t'"$rel"); fi
  done
  ((${#plan[@]})) || return 0
  sync_review "${plan[@]}"
  gum confirm --affirmative Apply --negative Cancel "Apply ${#plan[@]} change(s)?" || return 0
  new_run
  N_COPY=0 N_BACKUP=0
  for p in "${plan[@]}"; do
    IFS=$'\t' read -r act n rel <<<"$p"
    if [[ $act == push ]]; then push_file "$n" "$rel"
    else pull_file "$n" "$rel"
    fi
  done
  MSG=$(summary synced)
  KEEP=1
  offer_commit
}

# ---- backups menu ---------------------------------------------------------

# "5 backups of 2 files · 12K · oldest 40 days" for the header.
backup_summary() {
  local n rel b mt sz count=0 bytes=0 oldest=0 now age
  declare -A files=()
  now=$(date +%s)
  while IFS=$'\t' read -r n rel b; do
    read -r mt sz < <(stat -c '%Y %s' -- "$b")
    ((++count))
    bytes=$((bytes + sz))
    files["$n/$rel"]=1
    age=$(((now - mt) / 86400))
    if ((age > oldest)); then oldest=$age; fi
  done < <(backups)
  if ((count == 0)); then
    echo "  ${D}no backups yet. They appear when a push replaces a different file.${X}"
  else
    echo "  ${B}$count${X} backup(s) of ${B}${#files[@]}${X} file(s) · $(numfmt --to=iec --suffix=B "$bytes") · oldest $oldest day(s)"
    echo "  ${D}$(short "$BACKUP_DIR")${X}"
  fi
}

# fzf rows, newest first: "file  date  age  size", then backup path, current
# path, folder and file as hidden tab-separated fields.
backup_rows() {
  local n rel b mt sz age ago where now
  now=$(date +%s)
  while IFS=$'\t' read -r n rel b; do
    read -r mt sz < <(stat -c '%Y %s' -- "$b")
    age=$(((now - mt) / 86400))
    case $age in
      0) ago=today ;;
      1) ago=yesterday ;;
      *) ago="$age days ago" ;;
    esac
    where=
    if [[ $b != "$BACKUP_DIR"/* ]]; then where="  (beside the file)"; fi
    printf '%s\t%-34s %s  %-12s %5s%s\t%s\t%s\t%s\t%s\n' "$mt" "$n/$rel" "$(date -r "$b" '+%F %H:%M')" \
      "$ago" "$(numfmt --to=iec --suffix=B "$sz")" "$where" "$b" "$(dest_of "$n" "$rel")" "$n" "$rel"
  done < <(backups) | sort -rn -t$'\t' -k1,1 | cut -f2-
}

# Pick one backup, preview it against the current file, restore it.
backup_restore_pick() {
  need_fzf || return 0
  local rows picked n rel b
  rows=$(backup_rows)
  if [[ -z $rows ]]; then MSG="no backups yet"; return 0; fi
  picked=$(fzf --layout=reverse --height=90% --delimiter=$'\t' --with-nth=1 --no-info \
    --prompt "" --pointer ">" --gutter ' ' --border=rounded \
    --header $'Type a folder or file name to filter. The current file is backed up first.\nenter restore · esc cancel · diff: - backup, + current file' \
    --preview "diff --color=always -u --label backup --label current {2} {3}; true" \
    --preview-window 'down,60%,wrap,border-top' <<<"$rows" || true)
  [[ -n $picked ]] || return 0
  IFS=$'\t' read -r _ b _ n rel <<<"$picked"
  N_COPY=0 N_BACKUP=0
  restore_backup "$n" "$rel" "$b"
  MSG=$(summary restored)
}

backup_clean_pick() {
  local choice days
  choice=$(choose "Delete backups older than" \
    "7 days|Keep only the last week of backups." \
    "30 days|Keep only the last month of backups." \
    "90 days|Keep only the last three months of backups." \
    "Back|Return to the backups menu.") || return 0
  [[ $choice == Back ]] && return 0
  days=${choice%% *}
  clean_backups "$days" confirm
  pause
}

menu_backups() {
  local choice
  while true; do
    clear
    printf '\n  %sBackups%s\n\n' "$B$CYA" "$X"
    backup_summary
    echo
    choice=$(choose "What do you want to do?" \
      "Restore a backup|Pick a backup (type a folder or file name to filter), preview the diff and bring it back." \
      "Delete old backups|Remove backups older than 7, 30 or 90 days, after confirming." \
      "Back|Return to the main menu.") || return 0
    case $choice in
      "Restore a backup") backup_restore_pick; return 0 ;;
      "Delete old backups") backup_clean_pick ;;
      *) return 0 ;;
    esac
  done
}

# Tick the files that should sync. Unticked files are written to
# .dotfilesignore as exact paths; other lines there (comments, globs) stay.
menu_select() {
  need_fzf || return 0
  local f; f=$(pfile .dotfilesignore); local n rel path rows=() paths=() i preselect=load:select-all
  local picked=() skipped=0 synced=0 pattern
  declare -A keep=()
  while read -r n; do
    while IFS= read -r -d '' rel; do
      path=$n/$rel
      matches_any "$path" "${ALWAYS_IGNORE[@]}" && continue
      paths+=("$path")
    done < <(cd "$(src_dir "$n")" && find . \( -type f -o -type l \) -printf '%P\0' | sort -z)
  done < <(entries)
  for i in "${!paths[@]}"; do
    if matches_any "${paths[i]}" "${USER_IGNORE[@]}"; then preselect+="+pos($((i + 1)))+deselect"; fi
  done
  preselect+="+pos(1)"
  mapfile -t picked < <(printf '%s\n' "${paths[@]}" | fzf --multi --layout=reverse --height=90% --no-info \
    --prompt "syncs > " --pointer ">" --marker "+" --bind "$preselect" \
    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
    --header $'ticked files are synced · tab toggles · type a folder name, then ctrl-a, to tick it all\nenter saves to .dotfilesignore · esc cancels' || true)
  ((${#picked[@]})) || { MSG="nothing ticked, nothing changed"; return 0; }
  for path in "${picked[@]}"; do keep[$path]=1; done
  touch "$f"
  for path in "${paths[@]}"; do
    if [[ -n ${keep[$path]:-} ]]; then
      matches_any "$path" "${USER_IGNORE[@]}" || continue
      if grep -qxF -- "$path" "$f"; then
        grep -vxF -- "$path" "$f" >"$f.tmp" || true
        mv -f "$f.tmp" "$f"
        ((++synced))
      else
        pattern=$(printf '%s\n' "${USER_IGNORE[@]}" | while read -r p; do matches_any "$path" "$p" && echo "$p" && break; done)
        echo "  ${YEL}$path is skipped by the pattern '$pattern'; edit .dotfilesignore to change it${X}"
        pause
      fi
    else
      matches_any "$path" "${USER_IGNORE[@]}" && continue
      printf '%s\n' "$path" >>"$f"
      ((++skipped))
    fi
  done
  MSG="saved: $skipped file(s) now skipped, $synced synced again"
}

# Boilerplate folders a new profile can start from: apps/* and mango.
templates() {
  local d
  for d in "$ROOT"/apps/*/ "$ROOT"/apps/.[!.]*/ "$ROOT"/mango/; do
    [[ -d $d ]] && echo "${d%/}"
  done
}

# Copy boilerplate folders into profiles/NAME/ and switch to it.
profile_new() { # name [folder..]
  local name=$1 t f g
  shift
  [[ $name =~ ^[A-Za-z0-9._-]+$ && $name != auto && $name != none ]] || die "bad profile name '$name'"
  [[ ! -e $ROOT/profiles/$name ]] || die "profile '$name' already exists"
  local want=("$@")
  if ((${#want[@]} == 0)); then
    while read -r t; do [[ $t == "$ROOT"/mango ]] || want+=("$(basename "$t")"); done < <(templates)
  fi
  for f in "${want[@]}"; do
    t=$ROOT/apps/$f
    [[ -d $t ]] || t=$ROOT/$f
    [[ -d $t && $f != profiles ]] || die "no boilerplate folder '$f' (see: $0 profile templates)"
    if ((DRY)); then echo "  would copy $f"; continue; fi
    mkdir -p "$ROOT/profiles/$name"
    cp -rP "$t" "$ROOT/profiles/$name/$f"
    echo "  ${GRN}copied${X} $f"
  done
  if ((DRY)); then return 0; fi
  {
    echo '# Groups of alternative apps. "group.X = a b c" defines one, "X = a" picks it;'
    echo '# only the picked app is synced, the rest stay in this folder. "all" syncs every one.'
    for g in "${DEFAULT_GROUPS[@]}"; do echo "group.${g%%=*} = ${g#*=}"; done
    for g in "${DEFAULT_GROUPS[@]}"; do echo "${g%%=*} = all"; done
  } >"$ROOT/profiles/$name/profile.conf"
  set_profile "$name"
  echo "${B}profile $name${X} created from the boilerplate and now active"
}

set_profile() { # auto | none | NAME
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$1" >"$PROFILE_FILE"
  resolve_profile
  load_profile_settings
  load_entries
}

menu_profile_new() {
  need_fzf || return 0
  local name picked=()
  name=$(gum input --placeholder "name, e.g. ubuntu" --header "New profile name") || return 0
  [[ -n $name ]] || return 0
  mapfile -t picked < <(templates | while read -r t; do basename "$t"; done |
    fzf --multi --layout=reverse --height=90% --no-info --prompt "copy > " --pointer ">" --marker "+" \
      --bind 'load:select-all' --header $'ticked folders are copied into the profile\ntab toggles · enter creates · esc cancels' || true)
  ((${#picked[@]})) || { MSG="nothing picked, no profile created"; return 0; }
  MSG=$(profile_new "$name" "${picked[@]}" 2>&1 | tail -1)
}

menu_profile() {
  local items=() p choice
  items+=("auto|Detect it from this machine (now: ${PROFILE:-none}).")
  while read -r p; do items+=("$p|Sync profiles/$p/ on this machine."); done < <(profiles_available)
  items+=("New profile|Start a profile for another OS by copying the boilerplate folders you pick."
    "none|Sync nothing on this machine." "Back|Keep the current profile.")
  choice=$(choose "Profile (now: ${PROFILE:-none})" "${items[@]}") || return 0
  case $choice in
    Back) return 0 ;;
    "New profile") menu_profile_new; return 0 ;;
  esac
  set_profile "$choice"
  MSG="profile: ${PROFILE:-none}"
}

menu_settings() {
  local k choice items=()
  if ((${#PREF_ORDER[@]} == 0)); then
    MSG="no groups in $(short "$(pfile profile.conf)"); add one with: $0 profile group NAME a b"
    return 0
  fi
  for k in "${PREF_ORDER[@]}"; do
    items+=("$k|Which $k this profile syncs: ${PREF_GROUPS[$k]}. Now: ${PREF[$k]:-all}.")
  done
  items+=("Back|Return to the tools menu.")
  k=$(choose "Profile settings ($PROFILE)" "${items[@]}") || return 0
  [[ $k == Back ]] && return 0
  items=("all|Sync every $k in this profile.")
  for choice in ${PREF_GROUPS[$k]}; do
    if [[ -d $(pfile "$choice") ]]; then items+=("$choice|Sync only $choice; the other ${k}s stay in the profile, unsynced."); fi
  done
  choice=$(choose "Preferred $k" "${items[@]}") || return 0
  set_pref "$k" "$choice"
  MSG="$k: $choice"
}

menu_tools() {
  local choice items=()
  items+=("Profile|Pick the profile for this machine, or start one from the boilerplate. Now: ${PROFILE:-none}."
    "Profile settings|Choose one app per group (terminal, editor, shell... as the profile defines them); only that one is synced."
    "What is skipped|List every file and folder that is not synced, and why."
    "Doctor|Check tools, .gitignore, broken links, old backups and the sync record.")
  if nix_managed; then
    items+=("NixOS: rebuild|Run nixos-rebuild switch for this repo's flake. The configs are deployed by Nix, not synced.")
  fi
  if omarchy_ready; then
    items+=("Omarchy: set up|Load custom.lua from hyprland.lua, link the plugin settings and install the plugins ($(omarchy_state))."
      "Omarchy: uninstall|Remove the Omarchy hook, links and plugins from hyprland.lua.")
  fi
  items+=("Back|Return to the main menu.")
  choice=$(choose "Tools" "${items[@]}") || return 0
  case $choice in
    Profile) menu_profile ;;
    "NixOS: rebuild") "$SELF" rebuild; pause ;;
    "Profile settings") [[ -n $PROFILE ]] && menu_settings ;;
    "What is skipped") skipped_report; pause ;;
    Doctor) doctor || true; pause ;;
    "Omarchy: set up") omarchy_setup; pause ;;
    "Omarchy: uninstall")
      if gum confirm "Remove the Omarchy hook, links and plugins?"; then
        omarchy_uninstall
        pause
      fi
      ;;
  esac
}

menu() {
  command -v gum >/dev/null || die "the menu needs gum (sudo pacman -S gum); or use: $0 help"
  local choice items run
  while true; do
    if ((KEEP)); then KEEP=0; echo; else clear; fi
    show_status
    DIFFS=$(changed_files all)
    next_step
    echo
    if [[ -n $MSG ]]; then echo "  $MSG"; echo; MSG=; fi
    items=("Sync|$(if ((PENDING)); then echo "Review the $PENDING file(s) that differ and apply them. Nothing changes until you confirm."; else echo "Everything is in sync."; fi)"
      "Backups|Restore a replaced file, or delete old backups."
      "Choose what syncs|Fine-grained: skip single files inside a folder. For whole folders or one terminal/editor use Tools > Profile settings. See docs/usage.md for the best way.")
    run=$(last_run)
    if [[ -n $run ]]; then
      items+=("Undo last sync|Put back what the run from $(run_time "$run") changed ($(run_changes "$run" | wc -l) change(s)).")
    fi
    items+=("Tools|Doctor and the Omarchy uninstall." "Quit|Leave the menu.")
    choice=$(choose "What next?" "${items[@]}") || break
    case $choice in
      Sync) menu_sync ;;
      Backups) menu_backups ;;
      "Choose what syncs") menu_select ;;
      "Undo last sync") undo_last confirm; pause ;;
      Tools) menu_tools ;;
      Quit) break ;;
    esac
  done
}

# ---- command line ---------------------------------------------------------

args=()
for a in "$@"; do
  case $a in
    -n | --dry-run) DRY=1 ;;
    -y | --yes) YES=1 ;;
    --json) JSON=1 ;;
    --commit) COMMIT=1 ;;
    -h | --help) args=(help) && break ;;
    -v | --version) args=(version) && break ;;
    *) args+=("$a") ;;
  esac
done
cmd=${args[0]:-menu}
names=("${args[@]:1}")

# Names given on the command line, or the default list from function $1.
targets() {
  if ((${#names[@]})); then printf '%s\n' "${names[@]}"; else "$1"; fi
}

# Stop early on a name that is not a managed folder or file.
check_names() {
  local t
  for t in "${names[@]}"; do
    resolve_target "$t" || die "unknown name '$t'. Known: $(entries | paste -sd' ')"
  done
}

# Run a folder function or a file function for each name.
run_targets() { # folder_fn file_fn default_list_fn
  local t
  while read -r t; do
    [[ -n $t ]] || continue
    resolve_target "$t"
    if [[ -n $T_REL ]]; then "$2" "$T_NAME" "$T_REL"; else "$1" "$T_NAME"; fi
  done < <(targets "$3")
}

# Exactly one NAME FILE pair, for preview and merge.
file_args() {
  ((${#names[@]} == 2)) || die "usage: $0 $cmd NAME FILE"
  check_names
}

case $cmd in
  menu) menu ;;
  status) if ((JSON)); then status_json; else show_status; fi ;;
  list)
    if [[ ${names[0]:-} == files ]]; then
      while read -r n; do
        while IFS= read -r -d '' rel; do echo "$n/$rel"; done < <(tracked "$n")
      done < <(entries)
    else
      entries
    fi
    ;;
  install | push)
    check_names
    run_targets install_entry push_file out_of_sync
    summary pushed
    ;;
  pull)
    check_names
    run_targets pull_entry pull_file config_edited
    summary pulled
    if ((COMMIT && ${#PULLED[@]})); then commit_pulled "$(commit_message)"; fi
    ;;
  fetch) fetch_report ;;
  diff)
    check_names
    run_targets diff_entry file_diff out_of_sync
    ;;
  preview)
    file_args
    file_diff "${names[0]}" "${names[1]}"
    ;;
  merge)
    file_args
    merge_file "${names[0]}" "${names[1]}"
    ;;
  backups)
    while IFS=$'\t' read -r n rel b; do echo "$n/$rel  $(short "$b")"; done < <(backups)
    ;;
  restore)
    if ((${#names[@]})); then
      check_names
      run_targets restore_entry restore_target true
      summary restored
    elif [[ -t 0 ]]; then
      backup_restore_pick
    else
      die "usage: $0 restore NAME/FILE.."
    fi
    ;;
  select) menu_select; echo "$MSG" ;;
  undo) undo_last ;;
  clean) clean_backups "${names[0]:-30}" ;;
  baseline) baseline ;;
  doctor) doctor ;;
  watch) watch_config "${names[@]}" ;;
  profile)
    if [[ ${names[0]:-} == templates ]]; then
      templates | while read -r t; do basename "$t"; done
      exit 0
    elif [[ ${names[0]:-} == new ]]; then
      ((${#names[@]} >= 2)) || die "usage: $0 profile new NAME [folder..]"
      profile_new "${names[@]:1}"
      exit 0
    elif [[ ${names[0]:-} == set ]]; then
      ((${#names[@]} == 3)) || die "usage: $0 profile set GROUP NAME|all"
      set_pref "${names[1]}" "${names[2]}"
      echo "${names[1]} = ${names[2]}"
      exit 0
    elif [[ ${names[0]:-} == group ]]; then
      ((${#names[@]} >= 4)) || die "usage: $0 profile group GROUP NAME NAME.."
      define_group "${names[@]:1}"
      echo "group.${names[1]} = ${names[*]:2}"
      exit 0
    elif ((${#names[@]})); then
      case ${names[0]} in
        auto | none) ;;
        *) [[ -d $ROOT/profiles/${names[0]} ]] || die "no profile '${names[0]}'. Available: $(profiles_available | paste -sd' ')" ;;
      esac
      set_profile "${names[0]}"
    fi
    echo "profile: ${PROFILE:-none}"
    echo "available: $(profiles_available | paste -sd' ')"
    for k in "${PREF_ORDER[@]}"; do echo "$k = ${PREF[$k]:-all}   (${PREF_GROUPS[$k]})"; done
    ;;
  edit)
    ed=${PREF[editor]:-}
    [[ -n $ed && $ed != all ]] || ed=${EDITOR:-nvim}
    command -v "$ed" >/dev/null || die "editor '$ed' not found (set one: $0 profile set editor NAME)"
    if ((${#names[@]})); then
      check_names
      resolve_target "${names[0]}"
      target=$(src_dir "$T_NAME")${T_REL:+/$T_REL}
    else
      target=$ROOT/profiles/${PROFILE:-none}
    fi
    exec "$ed" "$target"
    ;;
  rebuild)
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
    if ((DRY)); then
      echo "would run: nixos-rebuild dry-build --flake $flake --impure"
      nixos-rebuild dry-build --flake "$flake" --impure
    else
      nixos-rebuild switch --flake "$flake" --impure --sudo
    fi
    ;;
  map)
    while read -r n; do
      d=$(dest_of "$n" "")
      printf '  %-14s %s → %s\n' "$n" "$(short "$(src_dir "$n")")" "$(short "${d%/}")"
      for i in "${!MAP_SRC[@]}"; do
        if [[ ${MAP_SRC[i]} == "$n"/* ]]; then printf '  %-14s %s → %s\n' "" "${MAP_SRC[i]}" "$(short "${MAP_DST[i]}")"; fi
      done
    done < <(entries)
    ;;
  skipped) skipped_report ;;
  setup) omarchy_setup ;;
  uninstall) omarchy_uninstall ;;
  help) usage ;;
  version) echo "dotfiles $VERSION" ;;
  *) usage >&2; exit 2 ;;
esac
