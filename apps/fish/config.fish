# Main Fish Shell Configuration

# Make $SHELL (and anything launched from fish) point at fish, even when the
# session inherited bash from the display manager.
set -gx SHELL (status fish-path)

# bun
set -gx BUN_INSTALL "$HOME/.bun"

# Set up PATH (fish sources conf.d/*.fish automatically, so no manual loop here)
fish_add_path ~/.local/bin $BUN_INSTALL/bin
