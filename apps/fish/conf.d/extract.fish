# function: extract - Extract various archive formats with a single command.

# Usage: extract myfile.tar.gz
function extract
    set -l filename $argv[1]

    if test -z "$filename"
        echo "Usage: extract <file>" >&2
        return 1
    end

    if not test -f "$filename"
        echo "No such file: $filename" >&2
        return 1
    end

    switch $filename
        case "*.tar.gz" "*.tgz"
            tar -xzf "$filename"
        case "*.tar.xz" "*.txz"
            tar -xJf "$filename"
        case "*.tar.bz2" "*.tbz2" "*.tbz"
            tar -xjf "$filename"
        case "*.tar"
            tar -xf "$filename"
        case "*.zip"
            unzip "$filename"
        case "*.rar"
            unrar x "$filename"
        case "*.7z"
            7z x "$filename"
        case "*"
            echo "Unknown file type: $filename" >&2
            return 1
    end

    or return 1

    echo "✓ Extracted: $filename"
end
