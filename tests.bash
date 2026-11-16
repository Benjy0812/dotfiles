#!/usr/bin/env bash
# Black-box tests for dotfiles.bash in a temp repo copy and a temp HOME.
# Usage: ./tests.bash   (exit code 1 if any test fails)
set -uo pipefail
command -v stow >/dev/null || { echo "stow not installed: sudo pacman -S stow" >&2; exit 1; }
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/dotfiles.bash"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME=$T/home XDG_STATE_HOME=$T/state DOTFILES_PROFILE=p
unset XDG_CONFIG_HOME
C=$HOME/.config R=$T/repo/profiles/p D=$T/repo/dotfiles.bash
fails=0

check() { # name command..
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "  ok    $name"; else echo "  FAIL  $name"; ((++fails)); fi
}
links_to() { [[ -L $1 && $(readlink -f "$1") == "$(readlink -f "$2")" ]]; }

fresh() { # repo: p/hypr/a.lua, p/kitty/kitty.conf, p/kitty/README.md; ~/.config/hypr/omarchy.lua is not ours
  rm -rf "$T/repo" "$HOME"
  mkdir -p "$R/hypr" "$R/kitty" "$C/hypr"
  cp "$SRC" "$D"
  echo a >"$R/hypr/a.lua"
  echo k >"$R/kitty/kitty.conf"
  echo doc >"$R/kitty/README.md"
  echo stock >"$C/hypr/omarchy.lua"
}

fresh
before=$(find "$HOME" | sort)
"$D" link -n >/dev/null 2>&1
check "link -n changes nothing" test "$before" == "$(find "$HOME" | sort)"
"$D" link >/dev/null
check "link makes a per-file link in an existing dir" links_to "$C/hypr/a.lua" "$R/hypr/a.lua"
check "link leaves an unrelated file alone" test ! -L "$C/hypr/omarchy.lua" -a "$(cat "$C/hypr/omarchy.lua")" == stock
check "link creates a missing dir as a real dir" test -d "$C/kitty" -a ! -L "$C/kitty"
check "link makes a file link in the new dir" links_to "$C/kitty/kitty.conf" "$R/kitty/kitty.conf"
check "a nested README.md is not linked" test ! -e "$C/kitty/README.md"
"$D" unlink >/dev/null
check "unlink removes our links" test ! -e "$C/hypr/a.lua" -a ! -e "$C/kitty/kitty.conf"
check "unlink keeps the unrelated file" test "$(cat "$C/hypr/omarchy.lua")" == stock
check "unlink keeps the repo files" test -f "$R/hypr/a.lua"

fresh
"$D" link >/dev/null
echo new >"$C/hypr/extra.lua"
"$D" track hypr/extra.lua >/dev/null
check "track moves the file into the repo" test "$(cat "$R/hypr/extra.lua")" == new
check "track links it back" links_to "$C/hypr/extra.lua" "$R/hypr/extra.lua"
check "track refuses a link" bash -c "! '$D' track hypr/extra.lua"
check "track refuses a path outside ~/.config" bash -c "echo x >'$HOME/out'; ! '$D' track '$HOME/out'"

fresh
echo live >"$C/hypr/a.lua"
"$D" adopt >/dev/null
check "adopt pulls the live file into the repo" test "$(cat "$R/hypr/a.lua")" == live
check "adopt links it" links_to "$C/hypr/a.lua" "$R/hypr/a.lua"

((fails == 0)) && echo "all passed" || { echo "$fails failed"; exit 1; }
