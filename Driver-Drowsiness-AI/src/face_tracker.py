import cv2
import time
import numpy as np
import mediapipe as mp


# ==========================================================
# CONFIG
# ==========================================================

MODEL_PATH = "models/mediapipe/face_landmarker.task"

CAMERA_INDEX = 0

FRAME_WIDTH = 1280
FRAME_HEIGHT = 720

SMOOTHING = 0.35

WINDOW_NAME = "MINERVA - Facial Tracking"


# ==========================================================
# MEDIAPIPE
# ==========================================================

BaseOptions = mp.tasks.BaseOptions
VisionRunningMode = mp.tasks.vision.RunningMode

FaceLandmarker = mp.tasks.vision.FaceLandmarker
FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions


options = FaceLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path=MODEL_PATH
    ),
    running_mode=VisionRunningMode.VIDEO,
    num_faces=1,
    min_face_detection_confidence=0.5,
    min_face_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)

landmarker = FaceLandmarker.create_from_options(options)


# ==========================================================
# CAMERA
# ==========================================================

cap = cv2.VideoCapture(CAMERA_INDEX)

cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)
cap.set(cv2.CAP_PROP_FPS, 60)

if not cap.isOpened():
    print("Could not open webcam.")
    exit()


# ==========================================================
# LANDMARK SMOOTHING
# ==========================================================

previous_landmarks = None


def smooth_landmarks(landmarks):
    global previous_landmarks

    current = np.array(
        [[lm.x, lm.y, lm.z] for lm in landmarks],
        dtype=np.float32
    )

    if previous_landmarks is None:
        previous_landmarks = current
        return current

    smoothed = (
        SMOOTHING * current
        + (1.0 - SMOOTHING) * previous_landmarks
    )

    previous_landmarks = smoothed

    return smoothed


# ==========================================================
# EYE LANDMARKS
# ==========================================================

LEFT_EYE = [
    362, 385, 387, 263,
    373, 380, 374, 381
]

RIGHT_EYE = [
    33, 160, 158, 133,
    153, 144, 163, 7
]


# ==========================================================
# FACE MESH CONNECTIONS
# ==========================================================

# Main face contour
FACE_OVAL = [
    10, 338, 297, 332, 284, 251,
    389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377,
    152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127,
    162, 21, 54, 103, 67, 109
]

# Iris landmarks
LEFT_IRIS = [474, 475, 476, 477]
RIGHT_IRIS = [469, 470, 471, 472]


# ==========================================================
# HELPERS
# ==========================================================

def point(landmarks, index, width, height):
    x = int(landmarks[index][0] * width)
    y = int(landmarks[index][1] * height)

    return x, y


def draw_polyline(frame, landmarks, indices, color, thickness=1):
    h, w = frame.shape[:2]

    pts = np.array(
        [point(landmarks, i, w, h) for i in indices],
        dtype=np.int32
    )

    cv2.polylines(
        frame,
        [pts],
        True,
        color,
        thickness,
        cv2.LINE_AA
    )


def calculate_ear(landmarks, eye):
    """
    Approximate Eye Aspect Ratio.
    """

    h = np.linalg.norm(
        landmarks[eye[1]] - landmarks[eye[5]]
    )

    h2 = np.linalg.norm(
        landmarks[eye[2]] - landmarks[eye[4]]
    )

    w = np.linalg.norm(
        landmarks[eye[0]] - landmarks[eye[3]]
    )

    if w == 0:
        return 0.0

    return (h + h2) / (2.0 * w)


def draw_glow_line(frame, p1, p2):
    """
    Draws a subtle multi-pass line to make
    the mesh look smoother.
    """

    cv2.line(
        frame,
        p1,
        p2,
        (80, 80, 80),
        3,
        cv2.LINE_AA
    )

    cv2.line(
        frame,
        p1,
        p2,
        (220, 220, 220),
        1,
        cv2.LINE_AA
    )


# ==========================================================
# FPS
# ==========================================================

previous_time = time.perf_counter()

timestamp_ms = 0


# ==========================================================
# MAIN LOOP
# ==========================================================

while True:

    ret, frame = cap.read()

    if not ret:
        break

    # Mirror camera
    frame = cv2.flip(frame, 1)

    h, w = frame.shape[:2]

    # ------------------------------------------------------
    # FPS
    # ------------------------------------------------------

    current_time = time.perf_counter()

    fps = 1.0 / max(
        current_time - previous_time,
        0.0001
    )

    previous_time = current_time

    # ------------------------------------------------------
    # MEDIAPIPE IMAGE
    # ------------------------------------------------------

    rgb = cv2.cvtColor(
        frame,
        cv2.COLOR_BGR2RGB
    )

    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=rgb
    )

    timestamp_ms += 1

    result = landmarker.detect_for_video(
        mp_image,
        timestamp_ms
    )

    # ------------------------------------------------------
    # FACE FOUND
    # ------------------------------------------------------

    if result.face_landmarks:

        landmarks = smooth_landmarks(
            result.face_landmarks[0]
        )

        # ==================================================
        # FACE MESH
        # ==================================================

        # Draw every MediaPipe connection
        for connection in mp.tasks.vision.FaceLandmarksConnections.FACE_LANDMARKS_TESSELATION:

            start_idx = connection.start
            end_idx = connection.end

            p1 = point(
                landmarks,
                start_idx,
                w,
                h
            )

            p2 = point(
                landmarks,
                end_idx,
                w,
                h
            )

            draw_glow_line(
                frame,
                p1,
                p2
            )

        # ==================================================
        # FACE OUTLINE
        # ==================================================

        draw_polyline(
            frame,
            landmarks,
            FACE_OVAL,
            (255, 255, 255),
            2
        )

        # ==================================================
        # EYES
        # ==================================================

        draw_polyline(
            frame,
            landmarks,
            RIGHT_EYE,
            (0, 255, 255),
            2
        )

        draw_polyline(
            frame,
            landmarks,
            LEFT_EYE,
            (0, 255, 255),
            2
        )

        # ==================================================
        # IRIS
        # ==================================================

        for iris in [LEFT_IRIS, RIGHT_IRIS]:

            for idx in iris:

                x, y = point(
                    landmarks,
                    idx,
                    w,
                    h
                )

                cv2.circle(
                    frame,
                    (x, y),
                    2,
                    (0, 255, 255),
                    -1,
                    cv2.LINE_AA
                )

        # ==================================================
        # EAR
        # ==================================================

        right_ear = calculate_ear(
            landmarks,
            RIGHT_EYE
        )

        left_ear = calculate_ear(
            landmarks,
            LEFT_EYE
        )

        ear = (left_ear + right_ear) / 2.0

        # ==================================================
        # FACE CENTER
        # ==================================================

        nose = point(
            landmarks,
            1,
            w,
            h
        )

        cv2.circle(
            frame,
            nose,
            4,
            (255, 255, 255),
            -1,
            cv2.LINE_AA
        )

        # ==================================================
        # HUD
        # ==================================================

        cv2.putText(
            frame,
            f"EAR  {ear:.3f}",
            (25, 35),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
            cv2.LINE_AA
        )

        cv2.putText(
            frame,
            f"FPS  {fps:.1f}",
            (25, 70),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
            cv2.LINE_AA
        )

        cv2.putText(
            frame,
            "FACE TRACKING : ACTIVE",
            (25, 105),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 255),
            2,
            cv2.LINE_AA
        )

    else:

        # Reset smoothing when face disappears
        previous_landmarks = None

        cv2.putText(
            frame,
            "FACE NOT DETECTED",
            (25, 45),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 0, 255),
            2,
            cv2.LINE_AA
        )

    # ======================================================
    # DISPLAY
    # ======================================================

    cv2.imshow(
        WINDOW_NAME,
        frame
    )

    key = cv2.waitKey(1) & 0xFF

    if key == ord("q"):
        break


# ==========================================================
# CLEANUP
# ==========================================================

cap.release()

landmarker.close()

cv2.destroyAllWindows()

print("Face tracker stopped.")