#!/usr/bin/env bash
# Black-box tests for dotfiles.bash. They run in a temp copy with a temp ~/.config,
# so nothing real is touched. Usage: ./tests.bash   (exit code 1 if any test fails)
set -uo pipefail
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/dotfiles.bash"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME=$T/home XDG_CONFIG_HOME=$T/home/.config XDG_STATE_HOME=$T/state NO_COLOR=1 DOTFILES_HOST=testhost
unset DOTFILES_PROFILE COLORTERM
fails=0 n=0

check() { # name command..   passes when the command succeeds
  local name=$1
  shift
  ((++n))
  if "$@" >/dev/null 2>&1; then echo "  ok    $name"; else echo "  FAIL  $name"; ((++fails)); fi
}
has() { grep -qF -- "$1" <<<"$2"; }

fresh() { # new repo + config with one tracked file: kitty/kitty.conf = "a"
  rm -rf "$T/repo" "$T/home" "$T/state"
  mkdir -p "$T/repo" "$T/home/.config/kitty"
  cp "$SRC" "$T/repo/dotfiles.bash"
  echo a >"$T/home/.config/kitty/kitty.conf"
  D="$T/repo/dotfiles.bash"
  "$D" profile new p >/dev/null
  "$D" track kitty >/dev/null
  "$D" baseline >/dev/null 2>&1
}

echo "states"
fresh
check "in sync after track" has "in sync" "$("$D" status)"
echo b >"$T/home/.config/kitty/kitty.conf"
check "edit in ~/.config is seen" has "edited in ~/.config" "$("$D" status)"
"$D" pull -y >/dev/null
check "pull copies it into the repo" grep -qx b "$T/repo/profiles/p/kitty/kitty.conf"
echo c >"$T/repo/profiles/p/kitty/kitty.conf"
check "edit in the repo is seen" has "repo is newer" "$("$D" status)"
"$D" push -y >/dev/null
check "push copies it to ~/.config" grep -qx c "$T/home/.config/kitty/kitty.conf"
check "push keeps a backup" has "kitty" "$(ls "$T/state/dotfiles/backups" 2>&1)"

echo "conflict"
fresh
echo repo >"$T/repo/profiles/p/kitty/kitty.conf"
echo live >"$T/home/.config/kitty/kitty.conf"
check "both sides changed is a conflict" has "both sides" "$("$D" status)"
"$D" pull -y >/dev/null
check "pull does not overwrite a conflict" grep -qx repo "$T/repo/profiles/p/kitty/kitty.conf"

echo "secrets"
fresh
echo 'api_token = "abcdefghijklmnop1234"' >"$T/home/.config/kitty/kitty.conf"
out=$("$D" pull -y)
check "pull holds back a new long secret" has "held back" "$out"
check "repo copy unchanged" grep -qx a "$T/repo/profiles/p/kitty/kitty.conf"
echo 'password = "hunter2x"' >"$T/home/.config/kitty/kitty.conf"
check "pull holds back a short secret" has "held back" "$("$D" pull -y)"
check "--force pulls it anyway" has "pulled" "$("$D" pull -y --force)"

echo "ignore"
fresh
echo x >"$T/home/.config/kitty/extra.conf"
"$D" track kitty >/dev/null
echo 'kitty/extra.conf' >"$T/repo/profiles/p/.dotfilesignore"
echo y >"$T/home/.config/kitty/extra.conf"
check "an ignored file is not reported" bash -c '! "$0" status | grep -q "edited"' "$D"
check "skipped lists it" has "kitty/extra.conf" "$("$D" skipped)"

echo "select saves once"
fresh
echo x >"$T/home/.config/kitty/extra.conf"
"$D" track kitty >/dev/null
mkdir -p "$T/bin"
printf '#!/bin/bash\ngrep -v -F kitty/extra.conf\n' >"$T/bin/fzf"
chmod +x "$T/bin/fzf"
for _ in 1 2 3; do PATH=$T/bin:$PATH "$D" select </dev/null >/dev/null; done
check "no duplicate ignore lines" test "$(grep -cx 'kitty/extra.conf' "$T/repo/profiles/p/.dotfilesignore")" = 1

echo "undo"
fresh
echo b >"$T/home/.config/kitty/kitty.conf"
"$D" pull -y >/dev/null
"$D" undo --yes >/dev/null
check "undo puts the repo file back" grep -qx a "$T/repo/profiles/p/kitty/kitty.conf"

echo layers
fresh
mkdir -p "$T/repo/profiles/global/starship"
echo g >"$T/repo/profiles/global/starship/starship.toml"
check "global-only folder is listed" has "starship" "$("$D" status)"
"$D" push starship >/dev/null
check "global folder is pushed" grep -qx g "$T/home/.config/starship/starship.toml"
echo edited >"$T/home/.config/starship/starship.toml"
"$D" pull starship >/dev/null
check "global folder is read only for pull" grep -qx g "$T/repo/profiles/global/starship/starship.toml"
check "OS copy wins by default" has "uses p" "$("$D" layer | grep kitty)"
"$D" layer kitty global >/dev/null
check "layer global copies the OS folder to global" test -f "$T/repo/profiles/global/kitty/kitty.conf"
check "layer global is used" has "uses global" "$("$D" layer | grep kitty)"
"$D" layer kitty os >/dev/null
check "layer os switches back" has "uses p" "$("$D" layer | grep kitty)"

echo
if ((fails)); then echo "$fails of $n failed"; exit 1; fi
echo "all $n passed"
