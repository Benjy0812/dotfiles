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
C=$HOME/.config R=$T/repo/profiles/p K=$T/repo/common D=$T/repo/dotfiles.bash
fails=0

check() { # name command..
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "  ok    $name"; else echo "  FAIL  $name"; ((++fails)); fi
}
links_to() { [[ -L $1 && $(readlink -f "$1") == "$(readlink -f "$2")" ]]; }

fresh() { # repo: p/hypr/a.lua, p/kitty/kitty.conf, p/kitty/README.md; ~/.config/hypr/omarchy.lua is not ours
  # common/: kitty/kitty.conf (the profile overrides it), kitty/theme.conf, git/config (common only), fish/fish_variables (never linked)
  rm -rf "$T/repo" "$HOME"
  mkdir -p "$R/hypr" "$R/kitty" "$C/hypr" "$K/kitty" "$K/git" "$K/fish"
  cp "$SRC" "$D"
  echo a >"$R/hypr/a.lua"
  echo k >"$R/kitty/kitty.conf"
  echo doc >"$R/kitty/README.md"
  echo shared >"$K/kitty/kitty.conf"
  echo theme >"$K/kitty/theme.conf"
  echo g >"$K/git/config"
  echo state >"$K/fish/fish_variables"
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
check "a common file is linked when the profile lacks it" links_to "$C/git/config" "$K/git/config"
check "common fills in next to profile files" links_to "$C/kitty/theme.conf" "$K/kitty/theme.conf"
check "the profile file wins over the common one" links_to "$C/kitty/kitty.conf" "$R/kitty/kitty.conf"
check "fish_variables is never linked" test ! -e "$C/fish/fish_variables"
"$D" link >/dev/null 2>&1
check "link runs again cleanly" links_to "$C/git/config" "$K/git/config"
"$D" unlink >/dev/null
check "unlink removes our links" test ! -e "$C/hypr/a.lua" -a ! -e "$C/kitty/kitty.conf" -a ! -e "$C/git/config" -a ! -e "$C/kitty/theme.conf"
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

fresh
rm "$R/kitty/kitty.conf"
"$D" link >/dev/null
echo mine >"$R/kitty/kitty.conf"
"$D" link >/dev/null 2>&1
check "a new profile file takes over a linked common one" links_to "$C/kitty/kitty.conf" "$R/kitty/kitty.conf"

if ((fails == 0)); then
  echo "all passed"
else
  echo "$fails failed"
  exit 1
fi
