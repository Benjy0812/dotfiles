# Completions for ~/Projects/dotfiles/dotfiles.bash, also when run as ./dotfiles.bash
set -l cmds link adopt unlink track setup uninstall rebuild profile help

function __dfs_complete
    complete -c dotfiles.bash $argv
    complete -p '*/dotfiles.bash' $argv
end

__dfs_complete -f
__dfs_complete -n "not __fish_seen_subcommand_from $cmds" -a "$cmds"
__dfs_complete -n "__fish_seen_subcommand_from track" -F
__dfs_complete -n "__fish_seen_subcommand_from profile" -a "auto (path basename ~/Projects/dotfiles/profiles/*/)"
__dfs_complete -n "__fish_seen_subcommand_from link rebuild" -s n -d 'Dry run, change nothing'
