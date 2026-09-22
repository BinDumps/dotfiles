#!/usr/bin/env bash
# Privacy App Inspector & Killer using Fuzzel (Nerd Font Icons)

set -euo pipefail

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

PW_DUMP_CMD="${PW_DUMP:-pw-dump}"
JQ_BIN="${JQ:-jq}"

declare -A PID_APP_MAP
declare -A PID_USAGE_MAP

# --- 1. CAMERA CHECK (/dev/video*) ---
if command -v fuser >/dev/null 2>&1; then
  CAM_PIDS=$(fuser /dev/video* 2>/dev/null | xargs || true)
  for pid in $CAM_PIDS; do
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      app_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "Unknown")
      PID_APP_MAP["$pid"]="$app_name"
      PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-}"
      [[ ! "${PID_USAGE_MAP[$pid]}" =~ "Camera" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]} Camera"
    fi
  done
fi

# --- 2. PIPEWIRE CHECK (Mic & Screenshare & Cam) ---
if command -v "$PW_DUMP_CMD" >/dev/null 2>&1 && command -v "$JQ_BIN" >/dev/null 2>&1; then
  dump="$($PW_DUMP_CMD 2>/dev/null || true)"

  if [ -n "$dump" ]; then
    while IFS=$'\t' read -r pid app_prop media_class node_name; do
      
      if [[ -z "$pid" ]] || [[ "$pid" -eq 0 ]]; then
        if [ -n "$app_prop" ]; then
          pid=$(pgrep -x "$app_prop" | head -n1 || echo 0)
        fi
      fi

      if [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$pid" -gt 0 ]]; then
        app_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "${app_prop:-Unknown}")
        PID_APP_MAP["$pid"]="$app_name"
        
        # Audio input (Microphone)
        if [[ "$media_class" =~ "Audio" ]] || [[ "$media_class" =~ "Stream/Input/Audio" ]] || [[ "$media_class" == "Audio/Source" ]]; then
          [[ ! "${PID_USAGE_MAP[$pid]:-}" =~ "Microphone" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-} Microphone"
        fi
        
        # Video input / Screenshare
        if [[ "$media_class" =~ "Video" ]] || [[ "$media_class" =~ "Stream/Input/Video" ]]; then
          if [[ "$node_name" =~ "portal" ]] || [[ "$node_name" =~ "screencast" ]] || [[ "$node_name" =~ "obs" ]]; then
            [[ ! "${PID_USAGE_MAP[$pid]:-}" =~ "ScreenShare" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-} ScreenShare"
          else
            [[ ! "${PID_USAGE_MAP[$pid]:-}" =~ "Camera" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-} Camera"
          fi
        fi
      fi
    done < <(echo "$dump" | $JQ_BIN -r '
      ( [ .[] | select(.type=="PipeWire:Interface:Client") | {id: .id, pid: (.info.props."pipewire.sec.pid" // .info.props."application.process.id" // 0), app: (.info.props."application.name" // .info.props."app.name" // "")} ] ) as $clients
      | .[]
      | select(.type=="PipeWire:Interface:Node")
      | select((.info.state=="running") or (.state=="running"))
      | . as $node
      | ($clients[] | select(.id == $node.info.props."client.id")) as $client
      | [
          ($node.info.props."pipewire.sec.pid" // $node.info.props."application.process.id" // $client.pid // 0),
          ($node.info.props."application.name" // $client.app // ""),
          ($node.info.props."media.class" // ""),
          ($node.info.props."node.name" // "")
        ]
      | @tsv
    ' 2>/dev/null || true)
  fi
fi

# --- 3. FALLBACK AUDIO RECORDING CHECK (/dev/snd/*) ---
if command -v fuser >/dev/null 2>&1; then
  SND_PIDS=$(fuser /dev/snd/pcm*c 2>/dev/null | xargs || true)
  for pid in $SND_PIDS; do
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      app_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "Unknown")
      PID_APP_MAP["$pid"]="$app_name"
      PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-}"
      [[ ! "${PID_USAGE_MAP[$pid]}" =~ "Microphone" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]} Microphone"
    fi
  done
fi

# --- 4. LOCATION CHECK (GeoClue) ---
if command -v dbus-send >/dev/null 2>&1; then
  if dbus-send --system --print-reply --dest=org.freedesktop.GeoClue2 \
     /org/freedesktop/GeoClue2/Manager org.freedesktop.DBus.Properties.Get \
     string:"org.freedesktop.GeoClue2.Manager" string:"InUse" 2>/dev/null | grep -q "boolean true"; then
     
     for pid in $(pgrep -u "$USER" -x "firefox|chromium|chrome|geoclue|telegram-desktop" || true); do
       if [[ "$pid" =~ ^[0-9]+$ ]]; then
         app_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "Unknown")
         PID_APP_MAP["$pid"]="$app_name"
         [[ ! "${PID_USAGE_MAP[$pid]:-}" =~ "Location" ]] && PID_USAGE_MAP["$pid"]="${PID_USAGE_MAP[$pid]:-} Location"
       fi
     done
  fi
fi

# --- 5. BUILD FUZZEL MENU (NERD FONT GLYPHS) ---
MENU_OPTIONS=""
for pid in "${!PID_APP_MAP[@]}"; do
  app="${PID_APP_MAP[$pid]}"
  raw_usage="${PID_USAGE_MAP[$pid]:-}"
  
  usage_tags=""
  [[ "$raw_usage" =~ "Microphone" ]] && usage_tags="${usage_tags} [󰍬 Mic]"
  [[ "$raw_usage" =~ "Camera" ]] && usage_tags="${usage_tags} [󰄀 Cam]"
  [[ "$raw_usage" =~ "ScreenShare" ]] && usage_tags="${usage_tags} [󰍹 Screen]"
  [[ "$raw_usage" =~ "Location" ]] && usage_tags="${usage_tags} [󰍎 Location]"
  
  if [ -n "$usage_tags" ]; then
    MENU_OPTIONS="${MENU_OPTIONS}${app} (PID: ${pid})${usage_tags}\n"
  fi
done

if [ -z "$MENU_OPTIONS" ]; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Privacy Monitor" "No active privacy-sensitive processes found." -i security-high
  fi
  exit 0
fi

# LAUNCH FUZZEL
SELECTED=$(printf "%b" "$MENU_OPTIONS" | fuzzel --dmenu --prompt="󰒃 Privacy Apps > " --width=60 --lines=8)

if [ -n "$SELECTED" ]; then
  TARGET_PID=$(echo "$SELECTED" | grep -oP '\(PID: \K[0-9]+(?=\))')
  APP_NAME=$(echo "$SELECTED" | awk '{print $1}')

  if [ -n "$TARGET_PID" ]; then
    ACTION=$(printf "󰅙 Terminate Process (SIGTERM)\n󰓛 Force Kill (SIGKILL)\n󰜺 Cancel" | fuzzel --dmenu --prompt="󰈸 Action for ${APP_NAME} (${TARGET_PID}) > " --width=45 --lines=3)
    
    case "$ACTION" in
      *"SIGTERM"*)
        kill "$TARGET_PID" && command -v notify-send >/dev/null 2>&1 && notify-send "Privacy Monitor" "Terminated ${APP_NAME} (PID: ${TARGET_PID})"
        ;;
      *"SIGKILL"*)
        kill -9 "$TARGET_PID" && command -v notify-send >/dev/null 2>&1 && notify-send "Privacy Monitor" "Force killed ${APP_NAME} (PID: ${TARGET_PID})"
        ;;
      *)
        exit 0
        ;;
    esac
  fi
fi
