#!/usr/bin/env bash
# dotfiles v1.2: compare this repo with ~/.config and sync the two. Each folder
# in apps/ and mango/ maps to ~/.config/<folder>/; omarchy/ is set up by
# omarchy/install.bash. Run `./dotfiles.bash help` for the commands.
set -euo pipefail

VERSION=1.2.0
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$ROOT/dotfiles.bash"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CONFIG/hypr"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$STATE_DIR/backups}" # one folder per file inside
SYNCED="$STATE_DIR/synced.tsv" # "name/file<TAB>sha256" as of the last push or pull
OMARCHY_SETTINGS=(monitor-workspaces.lua solo-workspaces.lua)
DRY=0 JSON=0 COMMIT=0 YES=0
N_COPY=0 N_BACKUP=0 # counted by push/pull/restore for the summary line
PULLED=()           # repo paths written by pulls, for the commit offer

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  B=$'\e[1m' D=$'\e[2m' RED=$'\e[31m' GRN=$'\e[32m' YEL=$'\e[33m' CYA=$'\e[36m' X=$'\e[0m'
else
  B= D= RED= GRN= YEL= CYA= X=
fi

die() { echo "${RED}$*${X}" >&2; exit 1; }
short() { echo "${1/#$HOME/\~}"; }

usage() {
  cat <<EOF
${B}dotfiles${X} v$VERSION: compare this repo with ~/.config and sync the two

${B}Usage${X}
  ./dotfiles.bash [command] [options] [name..]

${B}Commands${X}
  menu        interactive menu (default; needs gum, and fzf for the pickers)
  status      one row per folder: in sync, edited in ~/.config, newer in repo,
              changed on both sides (--json for scripts)
  fetch       list every file that differs, with +/- line counts; changes nothing
  push        copy repo files into ~/.config; replaced files are kept in the backup folder
              (install is the same command)
  pull        copy files edited in ~/.config back into the repo (--commit commits them)
  diff        show what differs
  merge NAME FILE     open both copies of a file in nvim -d
  preview NAME FILE   diff of one file (the pickers use it)
  backups     list the backups of tracked files
  restore     bring a backup back (NAME/FILE for the newest, or pick with fzf)
  clean [DAYS]  list backups older than DAYS (default 30); --yes deletes them
  baseline    record everything that is in sync as the common starting point
  doctor      check tools, .gitignore, backups and links
  watch       notify when a tracked file changes in ~/.config (--auto pulls it)
  uninstall   undo the Omarchy hook, links and plugins
  list [files]  print the folder names, or every tracked NAME/FILE
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

${B}Files${X} in the repo root: .dotfilesignore (paths to skip) and .dotfiles-hosts
(which folders belong on which machine). Both are optional.
EOF
}

# ---- what is managed ------------------------------------------------------

# Paths ("folder/file", globs allowed) that are never compared or copied.
IGNORE=('*/README.md' '*/install.bash' '*/fish_variables')
if [[ -f $ROOT/.dotfilesignore ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -n $line ]] && IGNORE+=("$line")
  done <"$ROOT/.dotfilesignore"
fi

ignored() {
  local p
  for p in "${IGNORE[@]}"; do
    # shellcheck disable=SC2053 # the pattern is meant to be a glob
    [[ $1 == $p ]] && return 0
  done
  return 1
}

# Every folder this repo has, one per line.
all_entries() {
  local d
  for d in "$ROOT"/apps/*/ "$ROOT"/apps/.[!.]*/; do
    [[ -d $d ]] && basename "$d"
  done
  echo mango
  echo omarchy
}

# Folders for this machine: all of them, unless .dotfiles-hosts has a
# "hostname: folder folder" line for it ("*" means all).
ENTRY_LIST=()
load_entries() {
  local host=${DOTFILES_HOST:-$(uname -n)} allowed= e w
  local keep=()
  mapfile -t ENTRY_LIST < <(all_entries)
  if [[ -f $ROOT/.dotfiles-hosts ]]; then
    allowed=$(awk -F: -v h="$host" '/^[[:space:]]*#/ {next} $1 == h {print $2}' "$ROOT/.dotfiles-hosts")
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
load_entries
entries() { printf '%s\n' "${ENTRY_LIST[@]}"; }

src_dir() { if [[ $1 == mango ]]; then echo "$ROOT/mango"; else echo "$ROOT/apps/$1"; fi; }

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
record_sync() { # key file
  if ((DRY)) || [[ -L $2 || ! -f $2 ]]; then return 0; fi
  mkdir -p "$STATE_DIR"
  local tmp
  tmp=$(mktemp "$STATE_DIR/.synced.XXXXXX")
  {
    if [[ -f $SYNCED ]]; then awk -F'\t' -v k="$1" '$1 != k' "$SYNCED"; fi
    printf '%s\t%s\n' "$1" "$(hash_of "$2")"
  } >"$tmp"
  mv -f "$tmp" "$SYNCED"
}

# same | missing | repo-newer | config-newer | conflict, for a repo file and its
# target. With a recorded sync, "conflict" means both sides changed since then;
# without one, the newer modification time decides.
state() {
  local s=$1 d=$2 base
  if [[ ! -e $d && ! -L $d ]]; then echo missing
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
    case "$(state "$dir/$rel" "$CONFIG/$1/$rel")" in
      same) ((++S_same)) ;;
      repo-newer) ((++S_repo)) ;;
      config-newer) ((++S_conf)) ;;
      conflict) ((++S_both)) ;;
      missing) ((++S_miss)) ;;
    esac
  done < <(tracked "$1")
}

# installed | partial | missing, for the Omarchy hook and the two settings links.
omarchy_state() {
  local ok=0 total=$((${#OMARCHY_SETTINGS[@]} + 1)) f
  if grep -qs 'omarchy/hypr/custom.lua' "$HYPR/hyprland.lua"; then ((++ok)); fi
  for f in "${OMARCHY_SETTINGS[@]}"; do
    if [[ "$(readlink "$HYPR/$f" 2>/dev/null)" == "$ROOT/omarchy/hypr/$f" ]]; then ((++ok)); fi
  done
  if ((ok == total)); then echo installed; elif ((ok > 0)); then echo partial; else echo missing; fi
}

# Names that need a push / have edits in ~/.config.
out_of_sync() {
  local n
  while read -r n; do
    if [[ $n == omarchy ]]; then
      if [[ "$(omarchy_state)" != installed ]]; then echo "$n"; fi
    else
      tally "$n"
      if ((S_repo + S_conf + S_both + S_miss > 0)); then echo "$n"; fi
    fi
  done < <(entries)
}
config_edited() {
  local n
  while read -r n; do
    [[ $n == omarchy ]] && continue
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
  local n label parts p
  printf '\n  %sdotfiles%s %sv%s%s  %s%s → %s%s  %s\n\n' "$B$CYA" "$X" "$D" "$VERSION" "$X" \
    "$D" "$(short "$ROOT")" "$(short "$CONFIG")" "$X" "$(repo_state)"
  while read -r n; do
    if [[ $n == omarchy ]]; then
      case "$(omarchy_state)" in
        installed) label="${GRN}✔ installed${X}" ;;
        partial) label="${YEL}◐ partly installed${X}" ;;
        *) label="${RED}✗ not installed${X}" ;;
      esac
    else
      tally "$n"
      parts=()
      if ((S_both)); then parts+=("${RED}⚠ $S_both changed on both sides${X}"); fi
      if ((S_conf)); then parts+=("${YEL}✎ $S_conf edited in ~/.config${X}"); fi
      if ((S_repo)); then parts+=("${CYA}↑ $S_repo newer in repo${X}"); fi
      if ((S_miss)); then parts+=("${RED}✗ $S_miss not installed${X}"); fi
      if ((${#parts[@]} == 0)); then
        label="${GRN}✔ in sync${X} ${D}($S_same files)${X}"
      else
        label=${parts[0]}
        for p in "${parts[@]:1}"; do label+=" ${D}·${X} $p"; done
      fi
    fi
    printf '  %-14s %s\n' "$n" "$label"
  done < <(entries)
  printf '\n'
}

status_json() {
  local n first=1
  printf '['
  while read -r n; do
    ((first)) || printf ','
    first=0
    if [[ $n == omarchy ]]; then
      printf '{"name":"omarchy","state":"%s"}' "$(omarchy_state)"
    else
      tally "$n"
      printf '{"name":"%s","in_sync":%d,"edited_in_config":%d,"newer_in_repo":%d,"conflict":%d,"not_installed":%d}' \
        "$n" "$S_same" "$S_conf" "$S_repo" "$S_both" "$S_miss"
    fi
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
    [[ $n == omarchy ]] && continue
    dir=$(src_dir "$n")
    while IFS= read -r -d '' rel; do
      st=$(state "$dir/$rel" "$CONFIG/$n/$rel")
      [[ $st == same ]] && continue
      [[ $1 == pull && $st == missing ]] && continue
      printf '%s\t%s\t%s\n' "$n" "$rel" "$st"
    done < <(tracked "$n")
  done < <(entries)
}

# Read-only preview of every differing file; +/- count lines of the
# ~/.config copy against the repo copy.
fetch_report() {
  local n rel st src dest add del stat total=0
  while IFS=$'\t' read -r n rel st; do
    src=$(src_dir "$n")/$rel dest=$CONFIG/$n/$rel
    stat=
    if [[ $st != missing && ! -L $src && ! -L $dest ]]; then
      add=$(diff "$src" "$dest" | grep -c '^>' || true)
      del=$(diff "$src" "$dest" | grep -c '^<' || true)
      stat=" ${GRN}+$add${X} ${RED}-$del${X}"
    fi
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
  fi
}

# One file, repo -> ~/.config; a different old file is kept as a backup.
push_file() { # name rel
  local src dest st
  src=$(src_dir "$1")/$2 dest=$CONFIG/$1/$2
  if [[ ! -e $src && ! -L $src ]]; then echo "  ${RED}not in the repo${X}  $1/$2"; return 0; fi
  st=$(state "$src" "$dest")
  [[ $st == same ]] && return 0
  if [[ $st != missing ]]; then stash "$1" "$2" "$dest"; fi
  echo "  ${GRN}copy${X}    $(short "$dest")"
  ((++N_COPY))
  if ((!DRY)); then
    mkdir -p "$(dirname "$dest")"
    cp -P "$src" "$dest"
    record_sync "$1/$2" "$dest"
  fi
}

# One file, ~/.config -> repo. Git is the undo, so no backup.
pull_file() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$CONFIG/$1/$2
  if [[ ! -e $src && ! -L $src ]]; then echo "  ${RED}not tracked in the repo${X}  $1/$2"; return 0; fi
  if [[ ! -e $dest && ! -L $dest ]]; then echo "  ${RED}not in ~/.config${X}  $1/$2"; return 0; fi
  [[ "$(state "$src" "$dest")" == same ]] && return 0
  echo "  ${YEL}pull${X}    $1/$2"
  ((++N_COPY))
  if ((!DRY)); then
    cp -P "$dest" "$src"
    PULLED+=("${src#"$ROOT"/}")
    record_sync "$1/$2" "$dest"
  fi
}

install_entry() {
  local name=$1 rel
  echo "${B}$name${X}"
  if [[ $name == omarchy ]]; then
    if ((DRY)); then echo "  would run omarchy/install.bash"; else "$ROOT/omarchy/install.bash"; fi
    return
  fi
  while IFS= read -r -d '' rel; do push_file "$name" "$rel"; done < <(tracked "$name")
}

# Every file edited in ~/.config and not changed in the repo since.
pull_entry() {
  local name=$1 rel
  if [[ $name == omarchy ]]; then echo "omarchy: nothing to pull (settings are linked)"; return; fi
  echo "${B}$name${X}"
  while IFS= read -r -d '' rel; do
    case "$(state "$(src_dir "$name")/$rel" "$CONFIG/$name/$rel")" in
      config-newer) pull_file "$name" "$rel" ;;
      conflict) echo "  ${RED}⚠ skipped${X}  $name/$rel changed on both sides (use merge, or pull the file by name)" ;;
    esac
  done < <(tracked "$name")
}

# Colored diff of one file: - is the repo copy, + is the ~/.config copy.
file_diff() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$CONFIG/$1/$2
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
  if [[ $name == omarchy ]]; then echo "omarchy: linked files, nothing to diff"; return; fi
  while IFS= read -r -d '' rel; do file_diff "$name" "$rel"; done < <(tracked "$name")
}

# Both copies side by side in nvim (left: repo, right: ~/.config); save the
# merged result into whichever side you want to keep, then push or pull it.
merge_file() { # name rel
  local src dest
  src=$(src_dir "$1")/$2 dest=$CONFIG/$1/$2
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
  names=$(printf '%s\n' "${PULLED[@]}" | awk -F/ '{print ($1 == "apps") ? $2 : $1}' | sort -u | paste -sd, | sed 's/,/, /g')
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
    [[ $n == omarchy ]] && continue
    while IFS= read -r -d '' rel; do
      dest=$CONFIG/$n/$rel
      # Per-file backup folder, plus .bak files left next to the file by older versions.
      for b in "$BACKUP_DIR/$n/$rel"/* "$dest".bak*; do
        if [[ -f $b || -L $b ]]; then printf '%s\t%s\t%s\n' "$n" "$rel" "$b"; fi
      done
    done < <(tracked "$n")
  done < <(entries)
}

latest_backup() { # name rel
  ls -t -- "$BACKUP_DIR/$1/$2"/* "$CONFIG/$1/$2".bak* 2>/dev/null | head -n1 || true
}

# Bring a backup back. The current file is backed up first, so nothing is lost.
restore_backup() { # name rel backup
  local dest=$CONFIG/$1/$2
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
    [[ $n == omarchy ]] && continue
    dir=$(src_dir "$n")
    while IFS= read -r -d '' rel; do
      if [[ "$(state "$dir/$rel" "$CONFIG/$n/$rel")" == same ]]; then
        record_sync "$n/$rel" "$CONFIG/$n/$rel"
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
  for c in inotifywait notify-send nvim; do
    if command -v "$c" >/dev/null; then d_ok "$c"; else d_warn "$c is missing (watch / merge)"; fi
  done

  echo "${B}repo${X}"
  if git -C "$ROOT" rev-parse >/dev/null 2>&1; then d_ok "git repository ($(repo_state))"; else d_bad "not a git repository"; fi
  while read -r n; do
    [[ $n == omarchy ]] && continue
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

# pick HEADER PRESELECTED_CSV NAME... -> chosen names, one per line
pick() {
  local header=$1 sel=$2
  shift 2
  local args=(--no-limit --header "$header" --cursor "> ")
  [[ -n $sel ]] && args+=(--selected "$sel")
  gum choose "${args[@]}" "$@"
}

need_fzf() {
  command -v fzf >/dev/null && return 0
  echo "  the file picker needs fzf (sudo pacman -S fzf)"
  pause
  return 1
}

menu_install() {
  local sel chosen name edited
  sel=$(out_of_sync | paste -sd,)
  mapfile -t chosen < <(pick "Push folders to ~/.config (space selects, enter confirms)" "$sel" $(entries))
  edited=$(config_edited)
  N_COPY=0 N_BACKUP=0
  for name in "${chosen[@]}"; do
    [[ -n $name ]] || continue
    if grep -qx "$name" <<<"$edited" && ((!DRY)); then
      gum confirm "$name has newer edits in ~/.config. Overwrite? (old files kept as backups)" || continue
    fi
    install_entry "$name"
  done
  summary pushed
  pause
}

# Pick single files with fzf, previewing each diff, then push or pull them.
# Keys: tab selects, ctrl-a all, ctrl-d none, ctrl-e opens nvim -d on the file.
menu_files() { # push | pull
  need_fzf || return 0
  local mode=$1 n rel st rows picked row warn=
  rows=$(while IFS=$'\t' read -r n rel st; do
    printf '%-38s %s\t%s\t%s\t%s\n' "$n/$rel" "$(tag_for "$st")" "$n" "$rel" "$st"
  done < <(changed_files "$mode"))
  if [[ -z $rows ]]; then echo "  nothing to $mode"; pause; return 0; fi
  mapfile -t picked < <(fzf --multi --ansi --layout=reverse --height=90% --delimiter=$'\t' --with-nth=1 \
    --prompt "$mode > " --pointer ">" --marker "+" \
    --header $'tab select · ctrl-a all · ctrl-d none · ctrl-e merge · enter confirm\ndiff: - repo, + ~/.config' \
    --preview "'$SELF' preview {2} {3}" --preview-window 'down,60%,wrap,border-top' \
    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
    --bind "ctrl-e:execute('$SELF' merge {2} {3})" <<<"$rows" || true)
  ((${#picked[@]})) || return 0
  for row in "${picked[@]}"; do
    if [[ $row == *$'\t'conflict ]]; then warn=" Some changed on both sides: the other copy is replaced."; fi
  done
  if [[ $mode == push ]]; then
    gum confirm "Push ${#picked[@]} file(s) to ~/.config?$warn (replaced files kept as backups)" || return 0
  else
    gum confirm "Pull ${#picked[@]} file(s) into the repo?$warn" || return 0
  fi
  N_COPY=0 N_BACKUP=0
  for row in "${picked[@]}"; do
    IFS=$'\t' read -r _ n rel _ <<<"$row"
    if [[ $mode == push ]]; then push_file "$n" "$rel"; else pull_file "$n" "$rel"; fi
  done
  summary "${mode}ed"
  offer_commit
  pause
}

# Preview what differs, then pull everything edited or pick single files.
menu_fetch() {
  local choice n
  fetch_report
  if [[ -z $(changed_files pull) ]]; then pause; return 0; fi
  choice=$(choose "Pull what?" \
    "Pick files|Choose single files, with a diff preview, to copy into the repo." \
    "All edited in ~/.config|Copy every file edited in ~/.config into the repo. Files changed on both sides are skipped." \
    "Back|Return to the main menu.") || return 0
  case $choice in
    "Pick files") menu_files pull ;;
    All*)
      if gum confirm "Copy every file edited in ~/.config into the repo?"; then
        N_COPY=0 N_BACKUP=0
        while read -r n; do [[ -n $n ]] && pull_entry "$n"; done < <(config_edited)
        summary pulled
        offer_commit
        pause
      fi
      ;;
  esac
}

menu_diff() {
  local name
  name=$(gum choose --header "Diff which folder?" --cursor "> " $(entries)) || return 0
  { diff_entry "$name"; echo; } | less -RFX
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
backup_rows() { # [folder]
  local n rel b mt sz age ago where now
  now=$(date +%s)
  while IFS=$'\t' read -r n rel b; do
    [[ -z ${1:-} || $n == "$1" ]] || continue
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
      "$ago" "$(numfmt --to=iec --suffix=B "$sz")" "$where" "$b" "$CONFIG/$n/$rel" "$n" "$rel"
  done < <(backups) | sort -rn -t$'\t' -k1,1 | cut -f2-
}

# Pick one backup, preview it against the current file, restore it.
backup_restore_pick() { # [folder]
  need_fzf || return 0
  local rows picked n rel b
  rows=$(backup_rows "${1:-}")
  if [[ -z $rows ]]; then echo "  no backups"; pause; return 0; fi
  picked=$(fzf --layout=reverse --height=90% --delimiter=$'\t' --with-nth=1 --no-info \
    --prompt "" --pointer ">" --gutter ' ' --border=rounded \
    --header $'Pick a backup to bring back. The current file is backed up first.\nenter restore · esc cancel · diff: - backup, + current file' \
    --preview "diff --color=always -u --label backup --label current {2} {3}; true" \
    --preview-window 'down,60%,wrap,border-top' <<<"$rows" || true)
  [[ -n $picked ]] || return 0
  IFS=$'\t' read -r _ b _ n rel <<<"$picked"
  N_COPY=0 N_BACKUP=0
  restore_backup "$n" "$rel" "$b"
  summary restored
  pause
}

# Choose a folder that has backups, then restore from just that folder.
backup_folder_pick() {
  local n rel b folder items=()
  declare -A count=()
  while IFS=$'\t' read -r n rel b; do count[$n]=$((${count[$n]:-0} + 1)); done < <(backups)
  if ((${#count[@]} == 0)); then echo "  no backups"; pause; return 0; fi
  for folder in $(printf '%s\n' "${!count[@]}" | sort); do
    items+=("$folder|${count[$folder]} backup(s) in $folder.")
  done
  items+=("Back|Return to the backups menu.")
  folder=$(choose "Restore from which folder?" "${items[@]}") || return 0
  [[ $folder == Back ]] && return 0
  backup_restore_pick "$folder"
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
      "Restore a file|Pick a backup, preview the diff against the current file and bring it back." \
      "Restore from a folder|Choose a folder first, then pick one of its backups to bring back." \
      "Delete old backups|Remove backups older than 7, 30 or 90 days, after confirming." \
      "Back|Return to the main menu.") || return 0
    case $choice in
      "Restore a file") backup_restore_pick ;;
      "Restore from a folder") backup_folder_pick ;;
      "Delete old backups") backup_clean_pick ;;
      *) return 0 ;;
    esac
  done
}

menu() {
  command -v gum >/dev/null || die "the menu needs gum (sudo pacman -S gum); or use: $0 help"
  local choice
  while true; do
    clear
    show_status
    choice=$(choose "What next?" \
      "Push folders to ~/.config|Copy whole folders from the repo into ~/.config. Replaced files are kept as backups." \
      "Push single files to ~/.config|Pick individual files, with a diff preview, and copy them from the repo into ~/.config." \
      "Fetch changes from ~/.config|Preview every file that differs, then pull your ~/.config edits back into the repo." \
      "Diff a folder|Colored diff for one folder: - is the repo copy, + is the ~/.config copy." \
      "Backups|Restore a file from a backup, or delete old backups. Shows how many there are." \
      "Doctor|Check tools, .gitignore, broken links, old backups and the sync record." \
      "Omarchy: uninstall|Remove the Omarchy hook, links and plugins from hyprland.lua." \
      "Refresh|Read ~/.config again and redraw the status table." \
      "Quit|Leave the menu.") || break
    case $choice in
      "Push folders"*) menu_install ;;
      "Push single"*) menu_files push ;;
      Fetch*) menu_fetch ;;
      "Diff a folder") menu_diff ;;
      Backups) menu_backups ;;
      Doctor) doctor || true; pause ;;
      Omarchy*)
        if gum confirm "Remove the Omarchy hook, links and plugins?"; then
          "$ROOT/omarchy/install.bash" uninstall
          pause
        fi
        ;;
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
    if [[ $T_NAME == omarchy && -n $T_REL ]]; then die "omarchy has no single files: $t"; fi
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
        [[ $n == omarchy ]] && continue
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
  clean) clean_backups "${names[0]:-30}" ;;
  baseline) baseline ;;
  doctor) doctor ;;
  watch) watch_config "${names[@]}" ;;
  uninstall)
    if ((DRY)); then echo "would run omarchy/install.bash uninstall"; else "$ROOT/omarchy/install.bash" uninstall; fi
    ;;
  help) usage ;;
  version) echo "dotfiles $VERSION" ;;
  *) usage >&2; exit 2 ;;
esac
