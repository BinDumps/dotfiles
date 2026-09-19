#!/bin/bash

THEME_DIR="$HOME/.local/share/themes"
NIRI_THEME_FILE="$HOME/.config/niri/theme-colors.kdl"

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
        WALLPAPER=$(find "$TARGET_DIR/wallpaper" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" \) | head -n 1)

        if [ -n "$WALLPAPER" ]; then
            awww img "$WALLPAPER"
        fi
    fi

    # Overwrite isolated theme-colors.kdl directly (Zero risk to main config)
    if [ -f "$TARGET_DIR/active-color.txt" ]; then
        COLOR_LINE=$(tr -d '\r\n' < "$TARGET_DIR/active-color.txt")

        cat << EOF > "$NIRI_THEME_FILE"
layout {
    focus-ring {
        $COLOR_LINE
    }
}
EOF
    fi

    # Gracefully reload Waybar
    pkill waybar && waybar &

    notify-send "Theme Switched" "Applied theme: $chosen"
else
    notify-send "Error" "Theme '$chosen' not found!"
fi
