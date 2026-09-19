#!/bin/bash

THEME_DIR="$HOME/.local/share/themes"
NIRI_CONFIG="$HOME/.config/niri/config.kdl"

# If an argument is passed directly, use it. Otherwise, use Fuzzel to pick one!
if [ -n "$1" ]; then
    chosen="$1"
else
    chosen=$(ls -1 "$THEME_DIR" | fuzzel --dmenu -p "Theme: ")
fi

[ -z "$chosen" ] && exit 0

TARGET_DIR="$THEME_DIR/$chosen"

if [ -d "$TARGET_DIR" ]; then
    # Copy theme files to live spots
    [ -f "$TARGET_DIR/style.css" ] && cp "$TARGET_DIR/style.css" "$HOME/.config/waybar/style.css"
    [ -f "$TARGET_DIR/fuzzel.ini" ] && cp "$TARGET_DIR/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
    [ -f "$TARGET_DIR/alacritty.toml" ] && cp "$TARGET_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

    # Copy Mako config & reload
    if [ -f "$TARGET_DIR/mako/config" ]; then
        mkdir -p "$HOME/.config/mako"
        cp "$TARGET_DIR/mako/config" "$HOME/.config/mako/config"
        makoctl reload
    fi

    # Set wallpaper using awww if wallpaper directory/file exists
    if [ -d "$TARGET_DIR/wallpaper" ]; then
        # Find first image file in wallpaper directory
        WALLPAPER=$(find "$TARGET_DIR/wallpaper" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" \) | head -n 1)

        if [ -n "$WALLPAPER" ]; then
            awww img "$WALLPAPER"
        fi
    fi

    # Update Niri focus-ring strictly inside focus-ring block
    if [ -f "$TARGET_DIR/active-color.txt" ] && [ -f "$NIRI_CONFIG" ]; then
        COLOR_LINE=$(tr -d '\r\n' < "$TARGET_DIR/active-color.txt")

        python3 - "$NIRI_CONFIG" "$COLOR_LINE" << 'EOF'
import sys, re

config_path = sys.argv[1]
new_line = sys.argv[2]

with open(config_path, 'r') as f:
    content = f.read()

# Match ONLY inside focus-ring { ... } block
def replace_in_focus_ring(match):
    block_content = match.group(1)
    updated_block = re.sub(
        r'(?m)^([ \t]*)(active-color|active-gradient)[ \t].*',
        r'\1' + new_line,
        block_content
    )
    return f"focus-ring {{\n{updated_block}\n}}"

new_content = re.sub(r'focus-ring\s*\{([^}]*)\}', replace_in_focus_ring, content, flags=re.DOTALL)

with open(config_path, 'w') as f:
    f.write(new_content)
EOF

        touch "$NIRI_CONFIG"
    fi

    # Gracefully reload Waybar
    pkill waybar && waybar &

    notify-send "Theme Switched" "Applied theme: $chosen"
else
    notify-send "Error" "Theme '$chosen' not found!"
fi
