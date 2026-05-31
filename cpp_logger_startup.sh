#!/bin/bash

set -e

echo "🚀 Starting Jetson pi camera service (C++)..."

# --------------------------------------------------
# PROJECT ROOT
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

CPP_FILE="$BASE_DIR/jetson_pi_cam_service.cpp"
EXECUTABLE="$BASE_DIR/jetson_pi_cam_service"

VIDEO_DIR="$BASE_DIR/camera"

LOG_FILE="$BASE_DIR/jetson_camera.log"
PID_FILE="$BASE_DIR/jetson_camera.pid"

echo "📁 Base: $BASE_DIR"
echo "💾 Video dir: $VIDEO_DIR"

# --------------------------------------------------
# CHECK FILES
# --------------------------------------------------
if [ ! -f "$CPP_FILE" ]; then
    echo "❌ jetson_pi_cam_service.cpp not found at $CPP_FILE"
    exit 1
fi

# --------------------------------------------------
# BUILD (AUTO COMPILE)
# --------------------------------------------------
echo "🔧 Building C++ camera service..."

g++ "$CPP_FILE" -o "$EXECUTABLE" \
    `pkg-config --cflags --libs opencv4` \
    -std=c++17

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed"
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

pkill -f "$EXECUTABLE" 2>/dev/null || true

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

# --------------------------------------------------
# START SERVICE
# --------------------------------------------------
echo "🎥 Launching camera service (LIVE)..."
cd "$BASE_DIR"

exec "$EXECUTABLE"