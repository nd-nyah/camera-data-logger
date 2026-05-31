#!/bin/bash

set -e

echo "🚀 Starting host camera service (Python2)..."

# --------------------------------------------------
# PROJECT ROOT (FIXED)
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

SCRIPT="$BASE_DIR/jetson_pi_cam_service.py"
VIDEO_DIR="$BASE_DIR/camera"

LOG_FILE="$BASE_DIR/host_camera.log"
PID_FILE="$BASE_DIR/host_camera.pid"

PYTHON="/usr/bin/python2"

echo "📁 Base: $BASE_DIR"
echo "💾 Video dir: $VIDEO_DIR"
echo "🐍 Python: $PYTHON"

# --------------------------------------------------
# CHECK FILES
# --------------------------------------------------
if [ ! -f "$SCRIPT" ]; then
    echo "❌ jetson_pi_cam_service.py not found at $SCRIPT"
    exit 1
fi

if [ ! -f "$PYTHON" ]; then
    echo "❌ Python2 not found at $PYTHON"
    exit 1
fi

# --------------------------------------------------
# STOP OLD INSTANCE
# --------------------------------------------------
echo "🛑 Stopping previous instance..."

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    kill -9 "$OLD_PID" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

pkill -f "$SCRIPT" 2>/dev/null || true

# --------------------------------------------------
# CLEAN OLD VIDEOS
# --------------------------------------------------
echo "🧹 Cleaning old recordings..."

if [ -d "$VIDEO_DIR" ]; then
    find "$VIDEO_DIR" -type f -name "*.mp4" -delete
    find "$VIDEO_DIR" -type f -name "*.mkv" -delete
    find "$VIDEO_DIR" -type f -name "*.avi" -delete
else
    mkdir -p "$VIDEO_DIR"
fi

echo "✅ Camera folder ready"

# --------------------------------------------------
# ENV VARS
# --------------------------------------------------
export VIDEO_DIR="$VIDEO_DIR"
export PYTHONUNBUFFERED=1

# --------------------------------------------------
# START (LIVE MODE)
# --------------------------------------------------
echo "🎥 Launching camera service (LIVE)..."
cd "$BASE_DIR"

exec "$PYTHON" "$SCRIPT"