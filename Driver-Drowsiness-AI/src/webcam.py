import cv2
import time
import math
import threading
import json
from pathlib import Path
import winsound
import numpy as np
import mediapipe as mp

try:
    from src.vigidrive_integration import VigiDriveEpisodeTracker
    from src.firebase_auth import FirebaseAuthClient
    from src.firebase_heartbeat import FirebaseHeartbeatManager
    from src.firebase_violations import FirebaseViolationsClient
except ModuleNotFoundError:
    from vigidrive_integration import VigiDriveEpisodeTracker
    from firebase_auth import FirebaseAuthClient
    from firebase_heartbeat import FirebaseHeartbeatManager
    from firebase_violations import FirebaseViolationsClient


# ============================================================
# DRIVER DROWSINESS DETECTION
# ============================================================

MODEL_PATH = "models/mediapipe/face_landmarker.task"
CAMERA_INDEX = 0
CAMERA_WIDTH = 1280
CAMERA_HEIGHT = 720

EAR_THRESHOLD = 0.25
CLOSED_FRAMES_REQUIRED = 15
EAR_SMOOTHING = 0.65

MESH_ALPHA = 0.30
MESH_MIN_EDGE = 7.0
MESH_MAX_EDGE = 80.0

ALARM_FREQUENCY = 1400
ALARM_DURATION = 220
ALARM_PAUSE = 0.10


# ============================================================
# ALARM
# ============================================================

alarm_lock = threading.Lock()
alarm_running = False
ALARM_FILE = "alarm.wav"


def create_alarm_file():
    # Create a short WAV tone once so Windows can play it asynchronously.
    import wave
    import struct

    sample_rate = 44100
    samples = int(sample_rate * (ALARM_DURATION / 1000.0))
    amplitude = 16000

    with wave.open(ALARM_FILE, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for i in range(samples):
            value = int(
                amplitude
                * math.sin(
                    2 * math.pi
                    * ALARM_FREQUENCY
                    * i
                    / sample_rate
                )
            )
            wav.writeframes(struct.pack("<h", value))


def start_alarm():
    global alarm_running

    with alarm_lock:
        if alarm_running:
            return

        if not Path(ALARM_FILE).exists():
            create_alarm_file()

        alarm_running = True

        # SND_LOOP + SND_ASYNC lets Windows loop the alarm without
        # blocking the OpenCV frame-processing loop.
        winsound.PlaySound(
            ALARM_FILE,
            winsound.SND_FILENAME
            | winsound.SND_ASYNC
            | winsound.SND_LOOP
        )


def stop_alarm():
    global alarm_running

    with alarm_lock:
        if not alarm_running:
            return

        # PlaySound(None, 0) stops the currently playing sound immediately.
        winsound.PlaySound(None, 0)
        alarm_running = False


# ============================================================
# MEDIAPIPE
# ============================================================

BaseOptions = mp.tasks.BaseOptions
FaceLandmarker = mp.tasks.vision.FaceLandmarker
FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode

options = FaceLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path=MODEL_PATH
    ),
    running_mode=RunningMode.VIDEO,
    num_faces=1,
    min_face_detection_confidence=0.5,
    min_face_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)

landmarker = FaceLandmarker.create_from_options(options)


# ============================================================
# LANDMARKS
# ============================================================

RIGHT_EYE = [33, 160, 158, 133, 153, 144]
LEFT_EYE = [362, 385, 387, 263, 373, 380]

RIGHT_IRIS = [469, 470, 471, 472]
LEFT_IRIS = [474, 475, 476, 477]

FALLBACK_FACE_OUTLINE = [
    10, 338, 297, 332, 284, 251, 389, 356,
    454, 323, 361, 288, 397, 365, 379, 378,
    400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21,
    54, 103, 67, 109
]


def connection_pairs(connection_set):
    pairs = []

    for c in connection_set:
        if hasattr(c, "start") and hasattr(c, "end"):
            pairs.append((int(c.start), int(c.end)))
        else:
            try:
                pairs.append(tuple(map(int, c)))
            except Exception:
                pass

    return pairs


connections_api = getattr(mp.tasks.vision, "FaceLandmarksConnections", None)

if connections_api:
    FACE_TESSELLATION = connection_pairs(
        getattr(
            connections_api,
            "FACE_LANDMARKS_TESSELATION",
            []
        )
    )

    FACE_CONTOURS = connection_pairs(
        getattr(
            connections_api,
            "FACE_LANDMARKS_CONTOURS",
            []
        )
    )
else:
    FACE_TESSELLATION = []
    FACE_CONTOURS = []


# ============================================================
# HELPERS
# ============================================================

def point(landmark, width, height):
    return (
        max(0, min(width - 1, int(landmark.x * width))),
        max(0, min(height - 1, int(landmark.y * height)))
    )


def distance(a, b):
    return math.hypot(
        a[0] - b[0],
        a[1] - b[1]
    )


def calculate_ear(landmarks, indices):
    try:
        p1, p2, p3, p4, p5, p6 = (
            landmarks[i] for i in indices
        )
    except (IndexError, ValueError):
        return 0.0

    horizontal = math.hypot(
        p1.x - p4.x,
        p1.y - p4.y
    )

    if horizontal < 1e-9:
        return 0.0

    vertical_1 = math.hypot(
        p2.x - p6.x,
        p2.y - p6.y
    )

    vertical_2 = math.hypot(
        p3.x - p5.x,
        p3.y - p5.y
    )

    return (vertical_1 + vertical_2) / (2 * horizontal)


def draw_face_mesh(frame, landmarks):
    if not FACE_TESSELLATION:
        return

    h, w = frame.shape[:2]
    overlay = frame.copy()

    for a, b in FACE_TESSELLATION:
        if a >= len(landmarks) or b >= len(landmarks):
            continue

        p1 = point(landmarks[a], w, h)
        p2 = point(landmarks[b], w, h)
        length = distance(p1, p2)

        if MESH_MIN_EDGE <= length <= MESH_MAX_EDGE:
            cv2.line(
                overlay,
                p1,
                p2,
                (205, 205, 205),
                1,
                cv2.LINE_AA
            )

    cv2.addWeighted(
        overlay,
        MESH_ALPHA,
        frame,
        1 - MESH_ALPHA,
        0,
        frame
    )


def draw_face_contour(frame, landmarks):
    h, w = frame.shape[:2]

    if FACE_CONTOURS:
        for a, b in FACE_CONTOURS:
            if a >= len(landmarks) or b >= len(landmarks):
                continue

            cv2.line(
                frame,
                point(landmarks[a], w, h),
                point(landmarks[b], w, h),
                (245, 245, 245),
                1,
                cv2.LINE_AA
            )
        return

    points = [
        point(landmarks[i], w, h)
        for i in FALLBACK_FACE_OUTLINE
        if i < len(landmarks)
    ]

    if len(points) >= 3:
        cv2.polylines(
            frame,
            [np.array(points, dtype=np.int32)],
            True,
            (245, 245, 245),
            2,
            cv2.LINE_AA
        )


def draw_eye(frame, landmarks, indices):
    h, w = frame.shape[:2]

    points = [
        point(landmarks[i], w, h)
        for i in indices
        if i < len(landmarks)
    ]

    if len(points) < 2:
        return

    for i, p in enumerate(points):
        cv2.line(
            frame,
            p,
            points[(i + 1) % len(points)],
            (0, 255, 255),
            2,
            cv2.LINE_AA
        )

        cv2.circle(
            frame,
            p,
            2,
            (0, 255, 255),
            -1,
            cv2.LINE_AA
        )


def draw_iris(frame, landmarks, indices):
    valid = [
        landmarks[i]
        for i in indices
        if i < len(landmarks)
    ]

    if not valid:
        return

    h, w = frame.shape[:2]

    cx = int(sum(p.x for p in valid) / len(valid) * w)
    cy = int(sum(p.y for p in valid) / len(valid) * h)

    if 0 <= cx < w and 0 <= cy < h:
        cv2.circle(
            frame,
            (cx, cy),
            3,
            (255, 255, 255),
            -1,
            cv2.LINE_AA
        )


def text(
    frame,
    value,
    position,
    scale=0.7,
    thickness=2,
    color=(255, 255, 255)
):
    cv2.putText(
        frame,
        value,
        position,
        cv2.FONT_HERSHEY_SIMPLEX,
        scale,
        color,
        thickness,
        cv2.LINE_AA
    )


def draw_alert(frame):
    h, w = frame.shape[:2]

    cv2.rectangle(
        frame,
        (5, 5),
        (w - 6, h - 6),
        (0, 0, 255),
        8,
        cv2.LINE_AA
    )

    text(
        frame,
        "WAKE UP!",
        (w // 2 - 130, 75),
        1.25,
        4,
        (0, 0, 255)
    )


# ============================================================
# FIREBASE INITIALIZATION
# ============================================================

def load_firebase_config():
    """
    Load Firebase configuration from local config file.

    Returns:
        Tuple of (auth_client, heartbeat_manager, violations_client) or (None, None, None) if config missing
    """
    config_file = Path.home() / ".vigidrive" / "device_config.json"

    if not config_file.exists():
        print("[Firebase] No configuration found - running in offline mode")
        print(f"[Firebase] Run setup_device.py to enable Firebase integration")
        return None, None, None

    try:
        with open(config_file, "r") as f:
            config = json.load(f)

        project_id = config.get("projectId")
        api_key = config.get("apiKey")
        system_id = config.get("systemId")
        refresh_token = config.get("refreshToken")

        if not all([project_id, api_key, system_id, refresh_token]):
            print("[Firebase] Invalid configuration - missing required fields")
            return None, None, None

        # Initialize Firebase Auth client
        auth_client = FirebaseAuthClient(api_key)
        auth_client.refresh_token = refresh_token

        # Get initial ID token to verify credentials
        try:
            auth_client.get_valid_id_token()
            print(f"[Firebase] Authenticated successfully")
        except Exception as e:
            print(f"[Firebase] Authentication failed: {e}")
            print("[Firebase] Run setup_device.py to reconfigure")
            return None, None, None

        # Initialize heartbeat manager
        heartbeat_manager = FirebaseHeartbeatManager(
            auth_client=auth_client,
            project_id=project_id,
            system_id=system_id,
        )

        # Initialize violations client
        violations_client = FirebaseViolationsClient(
            auth_client=auth_client,
            project_id=project_id,
            system_id=system_id,
        )

        print(f"[Firebase] Configured for system: {system_id}")
        return auth_client, heartbeat_manager, violations_client

    except Exception as e:
        print(f"[Firebase] Configuration error: {e}")
        return None, None, None


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 55)
    print("DRIVER DROWSINESS DETECTION")
    print("=" * 55)
    print("Press Q to quit.")

    # Initialize Firebase (optional - continues without it)
    auth_client, heartbeat_manager, violations_client = load_firebase_config()

    if heartbeat_manager:
        try:
            heartbeat_manager.start()
        except Exception as e:
            print(f"[Firebase] Failed to start heartbeat: {e}")
            heartbeat_manager = None

    cap = cv2.VideoCapture(CAMERA_INDEX)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)

    if not cap.isOpened():
        print("ERROR: Could not open camera.")
        landmarker.close()
        if heartbeat_manager:
            heartbeat_manager.stop()
        return

    previous_time = time.perf_counter()
    fps = 0.0
    left_smooth = None
    right_smooth = None
    closed_frames = 0
    timestamp = 0
    episode_tracker = VigiDriveEpisodeTracker(violations_client=violations_client)

    try:
        while True:
            ok, frame = cap.read()

            if not ok:
                break

            frame = cv2.flip(frame, 1)
            h, w = frame.shape[:2]

            now = time.perf_counter()
            delta = now - previous_time

            if delta > 0:
                instant_fps = 1 / delta
                fps = (
                    instant_fps
                    if fps == 0
                    else 0.90 * fps + 0.10 * instant_fps
                )

            previous_time = now

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            image = mp.Image(
                image_format=mp.ImageFormat.SRGB,
                data=rgb
            )

            timestamp = max(
                timestamp + 1,
                int(time.monotonic() * 1000)
            )

            try:
                result = landmarker.detect_for_video(
                    image,
                    timestamp
                )
            except Exception as error:
                print("MediaPipe error:", error)
                continue

            if result.face_landmarks:
                landmarks = result.face_landmarks[0]

                draw_face_mesh(frame, landmarks)
                draw_face_contour(frame, landmarks)

                draw_eye(frame, landmarks, LEFT_EYE)
                draw_eye(frame, landmarks, RIGHT_EYE)

                draw_iris(frame, landmarks, LEFT_IRIS)
                draw_iris(frame, landmarks, RIGHT_IRIS)

                left_ear = calculate_ear(
                    landmarks,
                    LEFT_EYE
                )

                right_ear = calculate_ear(
                    landmarks,
                    RIGHT_EYE
                )

                if left_smooth is None:
                    left_smooth = left_ear
                    right_smooth = right_ear
                else:
                    left_smooth = (
                        EAR_SMOOTHING * left_ear
                        + (1 - EAR_SMOOTHING) * left_smooth
                    )

                    right_smooth = (
                        EAR_SMOOTHING * right_ear
                        + (1 - EAR_SMOOTHING) * right_smooth
                    )

                average_ear = (
                    left_smooth + right_smooth
                ) / 2

                eyes_closed = (
                    left_smooth < EAR_THRESHOLD
                    and right_smooth < EAR_THRESHOLD
                )

                if eyes_closed:
                    closed_frames += 1
                else:
                    closed_frames = max(
                        0,
                        closed_frames - 2
                    )

                sleepy = (
                    closed_frames
                    >= CLOSED_FRAMES_REQUIRED
                )

                if sleepy:
                    status = "SLEEPY"
                    status_color = (0, 0, 255)
                    start_alarm()
                    episode_tracker.notify_sleepy()
                else:
                    status = "AWAKE"
                    status_color = (0, 255, 0)
                    stop_alarm()
                    episode_tracker.notify_awake()

                text(
                    frame,
                    status,
                    (20, 65),
                    1.0,
                    3,
                    status_color
                )

                text(
                    frame,
                    f"L: {left_smooth:.3f}",
                    (20, 105)
                )

                text(
                    frame,
                    f"R: {right_smooth:.3f}",
                    (20, 140)
                )

                text(
                    frame,
                    f"EAR: {average_ear:.3f}",
                    (20, 175)
                )

                count = min(
                    closed_frames,
                    CLOSED_FRAMES_REQUIRED
                )

                text(
                    frame,
                    f"Sleepy : {count}/{CLOSED_FRAMES_REQUIRED}",
                    (20, 215),
                    color=(0, 0, 255)
                )

                text(
                    frame,
                    f"Awake : "
                    f"{CLOSED_FRAMES_REQUIRED - count}/"
                    f"{CLOSED_FRAMES_REQUIRED}",
                    (20, 250),
                    color=(0, 255, 0)
                )

                text(
                    frame,
                    f"FPS : {fps:.1f}",
                    (20, 290)
                )

                text(
                    frame,
                    "FACE TRACKING : ACTIVE",
                    (20, 330),
                    color=(0, 255, 255)
                )

                if sleepy:
                    draw_alert(frame)

            else:
                stop_alarm()
                episode_tracker.notify_no_face()

                text(
                    frame,
                    "NO FACE DETECTED",
                    (20, 65),
                    0.9,
                    3,
                    (0, 165, 255)
                )

                text(
                    frame,
                    f"FPS : {fps:.1f}",
                    (20, 105)
                )

                closed_frames = max(
                    0,
                    closed_frames - 1
                )

                left_smooth = None
                right_smooth = None

            # Push frame to tracker (maintains rolling buffer and records during episodes)
            episode_tracker.push_frame(frame, fps if fps > 10 else 30.0)

            cv2.imshow(
                "Driver Drowsiness Detection",
                frame
            )

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    finally:
        stop_alarm()
        episode_tracker.finalize_now()
        cap.release()
        cv2.destroyAllWindows()
        landmarker.close()

        # Stop Firebase heartbeat (sets offline status)
        if heartbeat_manager:
            heartbeat_manager.stop()

    print("Driver drowsiness detection stopped.")


if __name__ == "__main__":
    main()