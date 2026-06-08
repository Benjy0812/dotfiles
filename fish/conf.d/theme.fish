# Fish Shell Theme & Colors

# Set color scheme (default is nice, but here are customizations)
# Colors available: black, red, green, yellow, blue, magenta, cyan, white

# Command syntax colors
set -U fish_color_command blue
set -U fish_color_param cyan
set -U fish_color_comment brgreen
set -U fish_color_keyword magenta

# Error colors
set -U fish_color_error red
set -U fish_color_selection white --background=brblack

# Prompt colors
set -U fish_color_status red

# Pager colors
set -U fish_pager_color_description yellow

# Greeting
function fish_greeting
end
