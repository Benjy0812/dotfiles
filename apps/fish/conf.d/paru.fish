# Custom wrapper for paru to allow using a number at the end of the command to specify a limit
function paru
    set -l args $argv
    set -l last_arg $argv[-1]

    # Check if last argument is a number
    if string match -qr '^\d+$' $last_arg
        # Remove the last number from args
        set args $argv[1..-2]
        # Run paru with --limit flag
        command paru $args --limit $last_arg
    else
        # No number at end, run normally
        command paru $argv
    end
end
