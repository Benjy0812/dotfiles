# Omarchy's bash setup (/usr/share/omarchy/default/bash/), redone for fish.
# PATH and OMARCHY_PATH already come from the session (uwsm), so this only
# covers what bash sets up per shell. Each part is skipped if its tool is
# missing, so the file is harmless outside Omarchy.

# Same defaults as Omarchy's bash envs: its editor and browser launchers,
# and bat for colored man pages.
if command -q omarchy-launch-editor
    set -q EDITOR; or set -gx EDITOR "omarchy-launch-editor --inline"
    set -gx SUDO_EDITOR $EDITOR
end
if command -q omarchy-launch-browser
    set -q BROWSER; or set -gx BROWSER omarchy-launch-browser
end
if command -q bat
    set -gx BAT_THEME ansi
    set -gx MANROFFOPT -c
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

# mise manages node, bun and friends; activate puts their versions on PATH.
command -q mise; and mise activate fish | source

status is-interactive; or return

# Prompt, smarter cd (`z dir`, `zi`), and fzf's Ctrl+R / Ctrl+T / Alt+C.
command -q starship; and starship init fish | source
command -q zoxide; and zoxide init fish | source
command -q fzf; and fzf --fish | source

# Omarchy's ls replacements, when eza is installed.
if command -q eza
    alias ls "eza -lh --group-directories-first --icons=auto"
    alias lsa "ls -a"
    alias lt "eza --tree --level=2 --long --icons --git"
    alias lta "lt -a"
end
