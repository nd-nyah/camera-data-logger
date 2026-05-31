#include <opencv2/opencv.hpp>
#include <iostream>
#include <filesystem>
#include <chrono>
#include <thread>
#include <ctime>

namespace fs = std::filesystem;

// --------------------------------------------------
// CONFIG
// --------------------------------------------------

const std::string VIDEO_DIR =
    std::string(getenv("HOME")) + "/camera-data-logger/camera";

const int WIDTH = 1280;
const int HEIGHT = 720;
const int FPS = 30;

const int SEGMENT_DURATION = 5;
const bool SHOW_PREVIEW = false;

// --------------------------------------------------
// TIMESTAMP
// --------------------------------------------------

std::string timestamp() {
    std::time_t t = std::time(nullptr);
    char buf[64];
    std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", std::localtime(&t));
    return std::string(buf);
}

// --------------------------------------------------
// CSI PIPELINE
// --------------------------------------------------

std::string camera_pipeline() {
    return
        "nvarguscamerasrc sensor-id=0 ! "
        "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1 ! "
        "nvvidconv ! "
        "video/x-raw, format=BGRx ! "
        "videoconvert ! "
        "video/x-raw, format=BGR ! "
        "appsink drop=true sync=false max-buffers=1";
}

// --------------------------------------------------
// WRITER PIPELINE
// --------------------------------------------------

cv::VideoWriter create_writer(std::string &out_path) {
    std::string ts = timestamp();
    out_path = VIDEO_DIR + "/recording_" + ts + ".mp4";

    std::string pipeline =
        "appsrc ! videoconvert ! "
        "video/x-raw,format=I420 ! "
        "x264enc bitrate=2000000 speed-preset=ultrafast tune=zerolatency ! "
        "mp4mux ! filesink location=" + out_path;

    cv::VideoWriter writer(
        pipeline,
        cv::CAP_GSTREAMER,
        0,
        FPS,
        cv::Size(WIDTH, HEIGHT),
        true
    );

    if (!writer.isOpened()) {
        throw std::runtime_error("Failed to open VideoWriter (GStreamer)");
    }

    std::cout << "🎥 Recording -> " << out_path << std::endl;
    return writer;
}

// --------------------------------------------------
// OPEN CAMERA
// --------------------------------------------------

cv::VideoCapture open_camera() {
    std::cout << "Opening CSI camera..." << std::endl;

    cv::VideoCapture cap(camera_pipeline(), cv::CAP_GSTREAMER);

    if (cap.isOpened()) {
        std::cout << "Camera opened" << std::endl;
        return cap;
    }

    std::cout << "Retrying camera..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(2));

    cap.open(camera_pipeline(), cv::CAP_GSTREAMER);

    if (!cap.isOpened()) {
        throw std::runtime_error("CSI camera failed permanently");
    }

    return cap;
}

// --------------------------------------------------
// MAIN
// --------------------------------------------------

int main() {
    std::cout << "🚀 Starting Jetson CSI camera service (C++)" << std::endl;

    if (!fs::exists(VIDEO_DIR)) {
        fs::create_directories(VIDEO_DIR);
    }

    cv::VideoCapture cap = open_camera();

    std::string file_path;
    cv::VideoWriter writer = create_writer(file_path);

    auto start = std::chrono::steady_clock::now();

    while (true) {
        cv::Mat frame;
        cap >> frame;

        if (frame.empty()) {
            std::cout << "Frame lost → reconnecting camera" << std::endl;
            cap.release();
            std::this_thread::sleep_for(std::chrono::seconds(2));
            cap = open_camera();
            continue;
        }

        writer.write(frame);

        if (SHOW_PREVIEW) {
            cv::imshow("CSI Camera", frame);
        }

        auto now = std::chrono::steady_clock::now();
        int elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();

        if (elapsed >= SEGMENT_DURATION) {
            std::cout << "💾 Saved: " << file_path << std::endl;

            writer.release();
            writer = create_writer(file_path);

            start = std::chrono::steady_clock::now();
        }

        if (cv::waitKey(1) == 27) { // ESC key
            break;
        }
    }

    cap.release();
    writer.release();
    cv::destroyAllWindows();

    std::cout << "Done" << std::endl;
    return 0;
}