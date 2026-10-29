# Function: mkcd - Create directory and enter it

# Usage: mkcd my-new-folder
function mkcd
    mkdir -p $argv
    cd $argv
end
