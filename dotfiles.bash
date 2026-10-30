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
HISTORY="$STATE_DIR/history.tsv" # "run<TAB>kind<TAB>name<TAB>file<TAB>saved copy", for undo
UNDO_DIR="$STATE_DIR/undo"       # repo files as they were before a pull
RUN_SEQ=0
OMARCHY_SETTINGS=(monitor-workspaces.lua solo-workspaces.lua)
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
  select        choose which files are synced (the rest go in .dotfilesignore)
  undo          put back what the last push, pull or restore changed (--yes to do it)

${B}More${X}
  fetch         list every file that differs, with +/- line counts; changes nothing
  merge NAME FILE  open both copies of a file in nvim -d
  backups       list the backups of tracked files
  clean [DAYS]  list backups older than DAYS (default 30); --yes deletes them
  baseline      record everything that is in sync as the common starting point
  doctor        check tools, .gitignore, backups and links
  watch         notify when a tracked file changes in ~/.config (--auto pulls it)
  uninstall     undo the Omarchy hook, links and plugins
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
ALWAYS_IGNORE=('*/README.md' '*/install.bash' '*/fish_variables')
USER_IGNORE=() # from .dotfilesignore, which the "Choose what syncs" menu edits
if [[ -f $ROOT/.dotfilesignore ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -n $line ]] && USER_IGNORE+=("$line")
  done <"$ROOT/.dotfilesignore"
fi

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
    src=$(src_dir "$n")/$rel dest=$CONFIG/$n/$rel
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
    if [[ $st == missing ]]; then log_change created "$1" "$2"; fi
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
    save_repo_copy "$1" "$2" "$src"
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
    dest=$CONFIG/$n/$rel src=$(src_dir "$n")/$rel
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

omarchy_pending() { [[ -d $ROOT/omarchy && $(omarchy_state) != installed ]]; }

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
  if omarchy_pending; then ((++m)); fi
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
    src=$(src_dir "$n")/$rel dest=$CONFIG/$n/$rel
    if [[ $rel == - ]]; then
      printf '  → ~/.config  %-34s link the hook and settings\n' "omarchy"
    elif [[ $act == push ]]; then
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
  if omarchy_pending; then
    safe+=("$(printf '%-38s %s\t%s\t-\t%s' "omarchy (hook and links)" "$(sync_tag missing)" omarchy missing)")
  fi
  if ((${#safe[@]} + ${#conf[@]} == 0)); then MSG="${GRN}everything is in sync${X}"; return 0; fi
  rows=$(printf '%s\n' "${safe[@]}" "${conf[@]}" | sed '/^$/d')
  preselect="load:select-all"
  for ((i = 1; i <= ${#conf[@]}; i++)); do preselect+="+pos(-$i)+deselect"; done
  preselect+="+pos(1)"
  mapfile -t picked < <(fzf --multi --ansi --layout=reverse --height=90% --delimiter=$'\t' --with-nth=1 \
    --prompt "sync > " --pointer ">" --marker "+" \
    --header $'ticked files are applied on enter · tab toggles · ctrl-a all · ctrl-d none · ctrl-e merge\ndiff: - repo, + ~/.config' \
    --preview "if [ {3} = - ]; then echo 'Links the Omarchy hook and settings (omarchy/install.bash).'; else '$SELF' preview {2} {3}; fi" \
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
    if [[ $rel == - ]]; then install_entry "$n"
    elif [[ $act == push ]]; then push_file "$n" "$rel"
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
      "$ago" "$(numfmt --to=iec --suffix=B "$sz")" "$where" "$b" "$CONFIG/$n/$rel" "$n" "$rel"
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
  local f=$ROOT/.dotfilesignore n rel path rows=() paths=() i preselect=load:select-all
  local picked=() skipped=0 synced=0 pattern
  declare -A keep=()
  while read -r n; do
    [[ $n == omarchy ]] && continue
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

menu_tools() {
  local choice
  choice=$(choose "Tools" \
    "Doctor|Check tools, .gitignore, broken links, old backups and the sync record." \
    "Omarchy: uninstall|Remove the Omarchy hook, links and plugins from hyprland.lua." \
    "Back|Return to the main menu.") || return 0
  case $choice in
    Doctor) doctor || true; pause ;;
    Omarchy*)
      if gum confirm "Remove the Omarchy hook, links and plugins?"; then
        "$ROOT/omarchy/install.bash" uninstall
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
      "Choose what syncs|Tick the files that should sync. Unticked ones are skipped.")
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
  select) menu_select; echo "$MSG" ;;
  undo) undo_last ;;
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
