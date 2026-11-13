# Function: mkcd - Create directory and enter it

# Usage: mkcd my-new-folder
function mkcd
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end
