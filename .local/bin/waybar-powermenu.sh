#!/usr/bin/env bash

SELECTION=$(echo -e "󰌾 Lock\n󰤄 Sleep\n󰜉 Reboot\n󰐥 Shutdown\n󰍃 Logout" | fuzzel --dmenu --prompt="Power: " -l 5 -w 20)

case "$SELECTION" in
    *"Lock")
        hyprlock ;;
    *"Sleep")
        hyprlock & systemctl suspend ;;
    *"Reboot")
        systemctl reboot ;;
    *"Shutdown")
        systemctl poweroff ;;
    *"Logout")
        niri msg action quit ;;
esac
