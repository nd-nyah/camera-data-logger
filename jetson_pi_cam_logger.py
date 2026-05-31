import cv2
import os
import time

# --------------------------------------------------
# CONFIG
# --------------------------------------------------

VIDEO_DIR = os.path.expanduser("~/camera-data-logger/camera")

WIDTH = 1280
HEIGHT = 720
FPS = 30

SEGMENT_DURATION = 5
SHOW_PREVIEW = False

if not os.path.exists(VIDEO_DIR):
    os.makedirs(VIDEO_DIR)

# --------------------------------------------------
# GSTREAMER PIPELINE (CSI CAMERA)
# --------------------------------------------------

def pipeline():
    return (
        "nvarguscamerasrc sensor-id=0 ! "
        "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1 ! "
        "nvvidconv ! "
        "video/x-raw, format=BGRx ! "
        "videoconvert ! "
        "video/x-raw, format=BGR ! "
        "appsink drop=true sync=false max-buffers=1"
    )

# --------------------------------------------------
# VIDEO WRITER (FIXED - GSTREAMER X264)
# --------------------------------------------------

def create_writer():
    ts = time.strftime("%Y%m%d_%H%M%S")
    path = os.path.join(VIDEO_DIR, "recording_" + ts + ".mp4")

    pipeline = (
        "appsrc ! videoconvert ! "
        "video/x-raw,format=I420 ! "
        "x264enc bitrate=2000000 speed-preset=ultrafast tune=zerolatency ! "
        "mp4mux ! filesink location="
        + path
    )

    writer = cv2.VideoWriter(
        pipeline,
        cv2.CAP_GSTREAMER,
        0,
        FPS,
        (WIDTH, HEIGHT),
        True
    )

    if not writer.isOpened():
        raise RuntimeError("GStreamer VideoWriter failed")

    print("Recording ->", path)
    return writer, path

# --------------------------------------------------
# CAMERA OPEN
# --------------------------------------------------

def open_camera():
    print("Opening CSI camera...")

    cap = cv2.VideoCapture(pipeline(), cv2.CAP_GSTREAMER)

    if cap.isOpened():
        print("Camera opened")
        return cap

    print("Retrying camera...")
    time.sleep(2)

    cap = cv2.VideoCapture(pipeline(), cv2.CAP_GSTREAMER)

    if not cap.isOpened():
        print("ERROR: CSI camera failed permanently")
        exit(1)

    return cap

# --------------------------------------------------
# START
# --------------------------------------------------

cap = open_camera()
out, file_path = create_writer()

start_time = time.time()

# --------------------------------------------------
# MAIN LOOP
# --------------------------------------------------

while True:

    ret, frame = cap.read()

    if not ret or frame is None:
        print("Frame lost → reconnecting camera")
        cap.release()
        time.sleep(2)
        cap = open_camera()
        continue

    out.write(frame)

    if SHOW_PREVIEW:
        cv2.imshow("CSI Camera", frame)

    # rotate file every SEGMENT_DURATION
    if time.time() - start_time >= SEGMENT_DURATION:

        print("Saved:", file_path)

        out.release()
        out, file_path = create_writer()

        start_time = time.time()

    if cv2.waitKey(1) & 0xFF in [27, ord('q')]:
        break

# --------------------------------------------------
# CLEANUP
# --------------------------------------------------

cap.release()
out.release()
cv2.destroyAllWindows()

print("Done")