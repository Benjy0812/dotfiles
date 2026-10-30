# Completions for ~/Projects/dotfiles/dotfiles.bash, also when run as ./dotfiles.bash
set -l dfs ~/Projects/dotfiles/dotfiles.bash
set -l cmds menu status list push install pull fetch diff preview merge backups restore clean baseline doctor watch uninstall select undo map profile edit setup help version

function __dfs_complete
    complete -c dotfiles.bash $argv
    complete -p '*/dotfiles.bash' $argv
end

__dfs_complete -f
__dfs_complete -n "not __fish_seen_subcommand_from $cmds" -a "$cmds"
__dfs_complete -n "__fish_seen_subcommand_from push install pull diff preview merge restore watch" \
    -a "($dfs list 2>/dev/null) ($dfs list files 2>/dev/null)"
__dfs_complete -n "__fish_seen_subcommand_from list" -a files
__dfs_complete -s n -l dry-run -d 'Show what would happen, change nothing'
__dfs_complete -s y -l yes -d 'Let clean delete'
__dfs_complete -l json -d 'status as JSON'
__dfs_complete -l commit -d 'pull: commit the pulled files'
__dfs_complete -l auto -d 'watch: pull edits automatically'
