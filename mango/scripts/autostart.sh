# !/bin/bash
# Autostart applications for MangoWM

# Start the noctalia-shell application in the background, suppressing output
dms run >/dev/null 2>&1 &

# Start the swaybg application with the specified image, suppressing output
swaybg -i ~/.config/mango/wall/1.png >/dev/null 2>&1 &
