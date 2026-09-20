#!/usr/bin/env bash

# Kill all background job processes on script exit
trap 'kill $(jobs -p) 2>/dev/null' EXIT INT TERM

# Dynamically parse any layout name into a clean 2-letter uppercase code
format_code() {
    local raw_name="$1"

    # 1. If layout name has code in parentheses like "English (US)", extract "US"
    if [[ "$raw_name" =~ \(([A-Za-z]{2})\) ]]; then
        echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'
        return
    fi

    # 2. Otherwise, take the first 2 letters of the layout name (e.g., "Russian" -> "RU")
    echo "$raw_name" | sed -E 's/[^a-zA-Z]//g' | cut -c1-2 | tr '[:lower:]' '[:upper:]'
}

# 1. Fetch initial state
INIT_JSON=$(niri msg --json keyboard-layouts 2>/dev/null)
if [ -n "$INIT_JSON" ]; then
    mapfile -t LAYOUT_NAMES < <(echo "$INIT_JSON" | jq -r '.names[]')
    CURRENT_IDX=$(echo "$INIT_JSON" | jq -r '.current_idx // 0')
    format_code "${LAYOUT_NAMES[$CURRENT_IDX]}"
else
    echo "EN"
fi

# 2. Listen to Niri event stream using Process Substitution
while read -r line; do
    if echo "$line" | grep -q "KeyboardLayoutsChanged"; then
        mapfile -t LAYOUT_NAMES < <(echo "$line" | jq -r '.KeyboardLayoutsChanged.keyboard_layouts.names[]')
        CURRENT_IDX=$(echo "$line" | jq -r '.KeyboardLayoutsChanged.keyboard_layouts.current_idx // 0')
        format_code "${LAYOUT_NAMES[$CURRENT_IDX]}"

    elif echo "$line" | grep -q "KeyboardLayoutSwitched"; then
        NEW_IDX=$(echo "$line" | jq -r '.KeyboardLayoutSwitched.idx // 0')
        format_code "${LAYOUT_NAMES[$NEW_IDX]}"
    fi
done < <(exec niri msg --json event-stream 2>/dev/null)
