# Main Fish Shell Configuration

# Set up PATH
set -gx PATH ~/.local/bin /usr/local/bin $PATH

# Auto-load all files from conf.d/
for file in ~/.config/fish/conf.d/*.fish
    source $file
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
