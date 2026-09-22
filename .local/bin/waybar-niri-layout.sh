#!/usr/bin/env bash

# --- Self-Deduplication: Kill any existing instances of this exact script ---
MY_PID=$$
for pid in $(pgrep -f "waybar-niri-layout.sh" 2>/dev/null || true); do
    if [ "$pid" -ne "$MY_PID" ]; then
        kill -9 "$pid" 2>/dev/null || true
    fi
done

# Terminate spawned background streams when process exits
trap 'pkill -P $$ 2>/dev/null; exit' EXIT INT TERM

format_code() {
    local raw_name="$1"

    if [[ "$raw_name" =~ \(([A-Za-z]{2})\) ]]; then
        echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]'
        return
    fi

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

# 2. Listen to Niri event stream using native PipeWire/Niri IPC stream
exec niri msg --json event-stream 2>/dev/null | while read -r line; do
    if echo "$line" | grep -q "KeyboardLayoutsChanged"; then
        mapfile -t LAYOUT_NAMES < <(echo "$line" | jq -r '.KeyboardLayoutsChanged.keyboard_layouts.names[]')
        CURRENT_IDX=$(echo "$line" | jq -r '.KeyboardLayoutsChanged.keyboard_layouts.current_idx // 0')
        format_code "${LAYOUT_NAMES[$CURRENT_IDX]}"

    elif echo "$line" | grep -q "KeyboardLayoutSwitched"; then
        NEW_IDX=$(echo "$line" | jq -r '.KeyboardLayoutSwitched.idx // 0')
        format_code "${LAYOUT_NAMES[$NEW_IDX]}"
    fi
done
