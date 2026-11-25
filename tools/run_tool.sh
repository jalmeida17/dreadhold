#!/bin/sh
# Runs a headless Godot tool script with a hard timeout and kills leftovers.
# usage: tools/run_tool.sh res://tools/gen_ui.gd [seconds] [-- user args]
SCRIPT="$1"; SECS="${2:-300}"; shift 2 2>/dev/null
cd "$(dirname "$0")/.." || exit 1
"/c/dev/Godot_v4.6-stable_mono_win64/Godot_v4.6-stable_mono_win64_console.exe" --headless --path . --script "$SCRIPT" "$@" 2>&1 &
PID=$!
( sleep "$SECS"; powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$SCRIPT*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" ) &
KILLER=$!
wait $PID
kill $KILLER 2>/dev/null
