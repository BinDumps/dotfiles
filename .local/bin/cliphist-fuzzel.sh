#!/usr/bin/env bash

if [ -z "$(cliphist list)" ]; then
    notify-send -a "Clipboard" "Clipboard History" "History is empty."
    exit 0
fi

# Step 1: Capture raw list
RAW_LIST=$(cliphist list)

# Display clean text in Fuzzel while preserving exact line positions
SELECTION=$(echo "$RAW_LIST" | sed -E 's/^[0-9]+\s+//' | fuzzel --dmenu --prompt="󰅌 Clipboard ❯ " --width=80 --lines=14)

[ -z "$SELECTION" ] && exit 0

# Retrieve exact line number selected in Fuzzel to extract corresponding cliphist item
LINE_NUM=$(echo "$RAW_LIST" | sed -E 's/^[0-9]+\s+//' | grep -n -F -m 1 "$SELECTION" | cut -d: -f1)
FULL_ITEM=$(echo "$RAW_LIST" | sed -n "${LINE_NUM}p")

# Step 2: Extract exact cliphist ID and full raw entry
ITEM_ID=$(echo "$FULL_ITEM" | cut -f1)

# Step 3: Check if selection is binary image data
if [[ "$SELECTION" =~ ^\[\[\ binary\ data ]]; then
    ACTION=$(echo -e "󰋩 Preview Image\n󰆏 Copy to Clipboard\n󰆴 Delete Entry\n󰃢 Clear All History" | fuzzel --dmenu --prompt="󰘵 Action ❯ " --width=30 --lines=4)
else
    ACTION=$(echo -e "󰆏 Copy to Clipboard\n󰆴 Delete Entry\n󰃢 Clear All History" | fuzzel --dmenu --prompt="󰘵 Action ❯ " --width=30 --lines=3)
fi

case "$ACTION" in
    *"Preview"*)
        if command -v swayimg &>/dev/null; then
            cliphist decode "$ITEM_ID" | swayimg - &
        elif command -v display &>/dev/null; then
            cliphist decode "$ITEM_ID" | display -immutable - &
        fi
        ;;
    *"Copy"*)
        echo "$FULL_ITEM" | cliphist decode | wl-copy
        notify-send -a "Clipboard" "Copied to clipboard"
        ;;
    *"Delete"*)
        # Pipe the full raw tab-separated entry directly into cliphist delete
        echo "$FULL_ITEM" | cliphist delete
        notify-send -a "Clipboard" "Entry deleted"
        ;;
    *"Clear"*)
        cliphist wipe
        notify-send -a "Clipboard" "Clipboard history cleared"
        ;;
esac
