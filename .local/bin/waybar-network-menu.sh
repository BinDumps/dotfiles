#!/usr/bin/env bash

# 1. Check Ethernet state
ETH_ACTIVE=$(nmcli -t -f TYPE,STATE device | grep "^ethernet:connected")

if [ -n "$ETH_ACTIVE" ]; then
    ACTIVE_ETH_NAME=$(nmcli -t -f TYPE,NAME,STATE device | grep "^ethernet:" | grep ":connected" | cut -d: -f2)
    SELECTION=$(echo -e "󰈀 Disconnect Ethernet ($ACTIVE_ETH_NAME)\n󰁪 Scan Wi-Fi Networks" | fuzzel --dmenu --prompt="Network: " -l 3 -w 35)

    case "$SELECTION" in
        *"Disconnect Ethernet"*)
            nmcli device disconnect "$ACTIVE_ETH_NAME"
            exit 0
            ;;
    esac
fi

# 2. Fetch current active Wi-Fi SSID
ACTIVE_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep "^yes:" | cut -d: -f2)

# Rescan Wi-Fi networks in background
nmcli dev wifi rescan 2>/dev/null

# Format list of available Wi-Fi networks: [SIGNAL%] SSID
WIFI_LIST=$(nmcli -f SIGNAL,SSID,SECURITY dev wifi list | sed 1d | awk 'NF>0 {
    sig=$1 "%"; 
    $1=""; 
    printf " %4s  %s\n", sig, $0
}' | sort -u -k2)

# 3. Prompt user for Wi-Fi selection
CHOSEN=$(echo -e "$WIFI_LIST" | fuzzel --dmenu --prompt="Wi-Fi: " -l 10 -w 50)

[ -z "$CHOSEN" ] && exit 0

# Parse selected SSID
SELECTED_SSID=$(echo "$CHOSEN" | awk '{
    for(i=2; i<=NF; i++) {
        if ($i ~ /\*/ || $i ~ /WPA/ || $i ~ /WEP/ || $i ~ /802.1X/ || $i ~ /--/) exit; 
        printf "%s ", $i
    }
}' | sed 's/ $//')

[ -z "$SELECTED_SSID" ] && exit 0

# Check if network is saved or active
IS_SAVED=$(nmcli -g NAME connection show | grep -x "$SELECTED_SSID")
IS_ACTIVE=0
[ "$SELECTED_SSID" = "$ACTIVE_SSID" ] && IS_ACTIVE=1

# 4. Handle sub-menu actions for active or saved networks
ACTION="Connect"

if [ $IS_ACTIVE -eq 1 ]; then
    # Active network options
    ACTION_CHOICE=$(echo -e "󰤨 Connect / Reconnect\n󰤭 Disconnect\n󰆴 Forget Network" | fuzzel --dmenu --prompt="$SELECTED_SSID: " -l 3 -w 35)
    case "$ACTION_CHOICE" in
        *"Disconnect"*) ACTION="Disconnect" ;;
        *"Forget Network"*) ACTION="Forget" ;;
        *"Connect"*) ACTION="Connect" ;;
        *) exit 0 ;;
    esac
elif [ -n "$IS_SAVED" ]; then
    # Saved network options
    ACTION_CHOICE=$(echo -e "󰤨 Connect\n󰆴 Forget Network" | fuzzel --dmenu --prompt="$SELECTED_SSID: " -l 2 -w 35)
    case "$ACTION_CHOICE" in
        *"Forget Network"*) ACTION="Forget" ;;
        *"Connect"*) ACTION="Connect" ;;
        *) exit 0 ;;
    esac
fi

# 5. Execute chosen action
case "$ACTION" in
    "Disconnect")
        nmcli device disconnect wlan0 2>/dev/null || nmcli connection down id "$SELECTED_SSID"
        ;;
    "Forget")
        nmcli connection delete id "$SELECTED_SSID"
        ;;
    "Connect")
        if [ -n "$IS_SAVED" ]; then
            nmcli connection up id "$SELECTED_SSID"
        else
            PASS=$(fuzzel --dmenu --password --prompt="Password for $SELECTED_SSID: " -l 0 -w 35)
            if [ -n "$PASS" ]; then
                nmcli dev wifi connect "$SELECTED_SSID" password "$PASS"
            else
                nmcli dev wifi connect "$SELECTED_SSID"
            fi
        fi
        ;;
esac
