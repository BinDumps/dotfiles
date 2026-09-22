#!/usr/bin/env bash
# Privacy dots for Waybar 
# Mic: green, Cam: orange, Location: blue

set -euo pipefail

JQ_BIN="${JQ:-jq}"
PW_DUMP_CMD="${PW_DUMP:-pw-dump}"
DBUS_SEND="${DBUS_SEND:-dbus-send}"

mic=0
cam=0
loc=0

# --- 1. MICROPHONE CHECK (PipeWire) ---
if command -v "$PW_DUMP_CMD" >/dev/null 2>&1 && command -v "$JQ_BIN" >/dev/null 2>&1; then
  dump="$($PW_DUMP_CMD 2>/dev/null || true)"

  if [ -n "$dump" ]; then
    mic="$(
      printf '%s' "$dump" \
      | $JQ_BIN -r '
        [ .[] 
          | select(.type=="PipeWire:Interface:Node")
          | select(
              (.info.props."media.class" == "Audio/Source") or 
              (.info.props."media.class" == "Audio/Source/Virtual") or 
              (.info.props."media.class" == "Stream/Input/Audio")
            )
          | select((.info.state == "running") or (.state == "running"))
        ] | if length > 0 then 1 else 0 end
      ' 2>/dev/null || echo 0
    )"
  fi
fi

# --- 2. CAMERA CHECK (V4L2 File Handles + PipeWire Native) ---
# Primary check: See if any process holds an open handle to /dev/video*
if command -v fuser >/dev/null 2>&1; then
  if fuser /dev/video* >/dev/null 2>&1; then
    cam=1
  fi
fi

# Secondary fallback: If fuser didn't catch it, check PipeWire nodes
if [[ $cam -eq 0 ]] && [ -n "${dump:-}" ]; then
  cam="$(
    printf '%s' "$dump" \
    | $JQ_BIN -r '
      [ .[] 
        | select(.type=="PipeWire:Interface:Node")
        | select(
            (.info.props."media.class" == "Video/Source") or
            (.info.props."media.class" == "Stream/Input/Video") or
            (.info.props."media.role" == "Camera")
          )
        | select((.info.state == "running") or (.state == "running"))
      ] | if length > 0 then 1 else 0 end
    ' 2>/dev/null || echo 0
  )"
fi

# --- 3. LOCATION CHECK (GeoClue2 D-Bus) ---
if command -v "$DBUS_SEND" >/dev/null 2>&1; then
  if $DBUS_SEND --system --print-reply --dest=org.freedesktop.GeoClue2 \
     /org/freedesktop/GeoClue2/Manager org.freedesktop.DBus.Properties.Get \
     string:"org.freedesktop.GeoClue2.Manager" string:"InUse" 2>/dev/null | grep -q "boolean true"; then
    loc=1
  fi
fi

# --- 4. FORMAT OUTPUT ---
green="#30D158"   # mic
orange="#FF9F0A"  # cam
blue="#0A84FF"    # location
grey="#555555"    # off

dot() {
  local on="$1" color="$2"
  if [[ "$on" -eq 1 ]]; then
    printf '<span foreground="%s">●</span>' "$color"
  else
    printf '<span foreground="%s">●</span>' "$grey"
  fi
}

text="$(dot "$mic" "$green") $(dot "$cam" "$orange") $(dot "$loc" "$blue")"
tooltip="Mic: $([[ $mic -eq 1 ]] && echo "on" || echo "off") | Cam: $([[ $cam -eq 1 ]] && echo "on" || echo "off") | Location: $([[ $loc -eq 1 ]] && echo "on" || echo "off")"

classes="privacydot"
[[ $mic -eq 1 ]] && classes="$classes mic-on" || classes="$classes mic-off"
[[ $cam -eq 1 ]] && classes="$classes cam-on" || classes="$classes cam-off"
[[ $loc -eq 1 ]] && classes="$classes loc-on" || classes="$classes loc-off"

$JQ_BIN -c -n --arg text "$text" --arg tooltip "$tooltip" --arg class "$classes" \
  '{text:$text, tooltip:$tooltip, class:$class}'
