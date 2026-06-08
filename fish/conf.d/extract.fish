# function: extract - Extract various archive formats with a single command.

# Usage: extract myfile.tar.gz
function extract
    set -l filename $argv[1]

    if test -z "$filename"
        echo "Usage: extract <file>"
        return 1
    end

    switch $filename
        case "*.tar.gz"
            tar -xzf $filename
        case "*.tar.bz2"
            tar -xjf $filename
        case "*.tar"
            tar -xf $filename
        case "*.zip"
            unzip $filename
        case "*.rar"
            unrar x $filename
        case "*.7z"
            7z x $filename
        case "*"
            echo "Unknown file type: $filename"
            return 1
    end

    echo "✓ Extracted: $filename"
end
