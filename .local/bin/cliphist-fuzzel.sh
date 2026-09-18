#!/usr/bin/env bash

# Check if history is empty
if [ -z "$(cliphist list)" ]; then
    notify-send -a "Clipboard" "Clipboard History" "History is empty."
    exit 0
fi

# Step 1: Display clipboard history with IDs hidden from view
# Fuzzel shows clean text; cliphist matches the selection seamlessly
SELECTION=$(cliphist list | sed -E 's/^[0-9]+\s+//' | fuzzel --dmenu --prompt="󰅌 Clipboard ❯ " --width=80 --lines=14)

# Exit if user pressed Escape or made no selection
[ -z "$SELECTION" ] && exit 0

# Retrieve the exact full item from cliphist using the clean text
FULL_ITEM=$(cliphist list | grep -F -m 1 "$SELECTION")

# Step 2: Choose action using clean Nerd Font icons
ACTION=$(echo -e "󰆏 Copy to Clipboard\n󰆴 Delete Entry\n󰃢 Clear All History" | fuzzel --dmenu --prompt="󰘵 Action ❯ " --width=30 --lines=3)

case "$ACTION" in
    *"Copy"*)
        echo "$FULL_ITEM" | cliphist decode | wl-copy
        notify-send -a "Clipboard" "Copied to clipboard"
        ;;
    *"Delete"*)
        echo "$FULL_ITEM" | cliphist delete
        notify-send -a "Clipboard" "Entry deleted"
        ;;
    *"Clear"*)
        cliphist wipe
        notify-send -a "Clipboard" "Clipboard history cleared"
        ;;
esac
