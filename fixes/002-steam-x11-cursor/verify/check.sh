#!/bin/sh
# Prints the theme X11 apps will resolve; fails if it is not what you set.
want="${1:-Bibata-Modern-Classic}"
got=$(sed -n 's/^Inherits=//p' "$HOME/.icons/default/index.theme" 2>/dev/null)
# shellcheck disable=SC2088 # printed for the reader, not used as a path
echo "~/.icons/default inherits: ${got:-<missing>}"
echo "XCURSOR_THEME: ${XCURSOR_THEME:-<unset>}"
[ "$got" = "$want" ] && echo OK || { echo "FAIL (want $want)"; exit 1; }
