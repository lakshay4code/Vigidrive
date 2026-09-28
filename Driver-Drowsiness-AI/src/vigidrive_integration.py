"""
vigidrive_integration.py
========================
VigiDrive local drowsiness episode tracker with rolling pre/post-event buffer.

Recording model
---------------
Every saved MP4 contains:

    ~PRE_EVENT_SECONDS (4 sec) before violation confirmed
    + full drowsiness episode duration
    + ~POST_EVENT_SECONDS (3 sec) after episode ends

                ┌───────────────┬──────────────────────────┬───────────────┐
                │  4 sec before │   Drowsiness episode    │  3 sec after  │
                └───────────────┴──────────────────────────┴───────────────┘
                                ↑                          ↑
                         violation confirmed           episode ends

No data is written to disk during normal awake operation.
The rolling buffer is bounded to PRE_EVENT_SECONDS and lives only in memory.
"""

import json
import queue
import threading
import time
import uuid
from collections import deque
from datetime import datetime, timezone
from enum import Enum, auto
from pathlib import Path
from typing import Any, Deque, Dict, Optional

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Configuration constants
# ---------------------------------------------------------------------------

PRE_EVENT_SECONDS: float = 4.0   # Rolling buffer window kept before violation
POST_EVENT_SECONDS: float = 3.0  # Extra recording window kept after episode ends

# Maximum frames queued for the background writer before drops occur.
# 180 ≈ 6 s at 30 fps — enough headroom for pre+post buffer flush plus latency.
_WRITER_QUEUE_MAXSIZE: int = 512


# ---------------------------------------------------------------------------
# Internal state machine
# ---------------------------------------------------------------------------

class _State(Enum):
    IDLE       = auto()  # Awake, no active episode
    ACTIVE     = auto()  # Drowsiness confirmed; recording in progress
    POST_EVENT = auto()  # Episode ended; 2-second tail still being recorded


# ---------------------------------------------------------------------------
# Rolling pre-event frame buffer
# ---------------------------------------------------------------------------

class RollingFrameBuffer:
    """
    A bounded circular buffer that retains approximately the last
    PRE_EVENT_SECONDS of camera frames.

    - Updated every frame via push().
    - Never grows beyond max_frames.
    - Drainable as a snapshot list (oldest-first) via drain().
    - Thread-safe for push() / drain() called from the same thread.
    """

    def __init__(self, fps: float, pre_event_seconds: float = PRE_EVENT_SECONDS) -> None:
        self._fps = max(1.0, fps)
        self._pre_event_seconds = pre_event_seconds
        self._max_frames = max(1, int(self._fps * self._pre_event_seconds))
        self._buf: Deque[np.ndarray] = deque(maxlen=self._max_frames)

    @property
    def max_frames(self) -> int:
        return self._max_frames

    def push(self, frame: np.ndarray) -> None:
        """Add the latest frame. Oldest frame is discarded automatically when full."""
        self._buf.append(frame.copy())

    def drain(self) -> list:
        """Return all buffered frames (oldest first) and clear the buffer."""
        frames = list(self._buf)
        self._buf.clear()
        return frames

    def __len__(self) -> int:
        return len(self._buf)


# ---------------------------------------------------------------------------
# Main tracker
# ---------------------------------------------------------------------------

class VigiDriveEpisodeTracker:
    """
    Manages the lifecycle of confirmed drowsiness episodes for VigiDrive.

    Lifecycle
    ---------
    IDLE
      push_frame()  →  rolling buffer keeps last PRE_EVENT_SECONDS; nothing written to disk
      notify_sleepy() →  dump pre-buffer + live frames to MP4; transition to ACTIVE

    ACTIVE
      push_frame()   →  live frames written to MP4 via background worker
      notify_sleepy() → no-op (already active)
      notify_awake() / notify_no_face() →  record end timestamp + duration;
                        transition to POST_EVENT; keep writing live frames

    POST_EVENT
      push_frame()   →  live frames continue being written (post-event tail)
      notify_sleepy() → cancel post-event countdown; back to ACTIVE (same recording)
      _post_event_elapsed? → finalize MP4 + write JSON; transition to IDLE

    The caller must call push_frame() every camera frame regardless of sleepy state.
    The caller drives the state machine by calling notify_sleepy() / notify_awake() /
    notify_no_face() based on the detector output.
    """

    def __init__(
        self,
        system_id: str = "LakshaysPC",
        driver_name: str = "Lakshay",
        project_root: Optional[Path] = None,
        pre_event_seconds: float = PRE_EVENT_SECONDS,
        post_event_seconds: float = POST_EVENT_SECONDS,
        violations_client=None,
    ) -> None:
        self.system_id = system_id
        self.driver_name = driver_name
        self.pre_event_seconds = pre_event_seconds
        self.post_event_seconds = post_event_seconds
        self.violations_client = violations_client

        if project_root is None:
            self.project_root = Path(__file__).resolve().parent.parent
        else:
            self.project_root = Path(project_root)

        self.recordings_dir = self.project_root / "recordings"
        self.events_dir = self.project_root / "events"
        self.recordings_dir.mkdir(parents=True, exist_ok=True)
        self.events_dir.mkdir(parents=True, exist_ok=True)

        # Public state flag — True only while episode is ACTIVE or POST_EVENT
        self.is_active: bool = False

        # Internal state machine
        self._state: _State = _State.IDLE

        # Rolling pre-event buffer (created/resized when fps is known)
        self._pre_buf: Optional[RollingFrameBuffer] = None

        # Episode metadata
        self._episode_id: Optional[str] = None
        self._start_perf: float = 0.0
        self._started_at_dt: Optional[datetime] = None
        self._ended_perf: float = 0.0    # when notify_awake() was called
        self._ended_at_dt: Optional[datetime] = None
        self._recording_path: Optional[Path] = None

        # Video writer (background threaded)
        self._frame_queue: Optional[queue.Queue] = None
        self._writer_thread: Optional[threading.Thread] = None
        self._video_writer: Optional[cv2.VideoWriter] = None
        self._frames_written: int = 0

        # Runtime fps + dimensions (set on first push_frame call)
        self._fps: float = 30.0
        self._width: int = 0
        self._height: int = 0

    # ------------------------------------------------------------------
    # Public API — called every camera frame
    # ------------------------------------------------------------------

    def push_frame(self, frame: np.ndarray, fps: float = 30.0) -> None:
        """
        Must be called every camera frame, regardless of sleepy/awake state.

        In IDLE state: updates the rolling pre-event buffer (no disk I/O).
        In ACTIVE / POST_EVENT: queues frame for background writer (non-blocking).
        """
        self._update_fps_dims(frame, fps)

        if self._state == _State.IDLE:
            # Maintain rolling pre-buffer; no disk I/O
            if self._pre_buf is not None:
                self._pre_buf.push(frame)

        elif self._state in (_State.ACTIVE, _State.POST_EVENT):
            self._enqueue_frame(frame)

            # In POST_EVENT: check if post-event window has elapsed
            if self._state == _State.POST_EVENT:
                elapsed = time.perf_counter() - self._ended_perf
                if elapsed >= self.post_event_seconds:
                    self._finalize()

    def notify_sleepy(self) -> None:
        """
        Called when the detector confirms drowsiness this frame.

        IDLE   → ACTIVE: dump pre-buffer + begin recording
        ACTIVE → no-op (already recording)
        POST_EVENT → cancel post-event tail; resume ACTIVE (same recording)
        """
        if self._state == _State.IDLE:
            self._begin_episode()

        elif self._state == _State.POST_EVENT:
            # Driver fell asleep again before post-event expired — resume episode
            print("[VigiDrive] Drowsiness resumed during post-event tail; resuming recording")
            self._state = _State.ACTIVE
            self.is_active = True
            # Clear ended timestamps so duration measurement restarts from here
            self._ended_perf = 0.0
            self._ended_at_dt = None

        # ACTIVE → no-op

    def notify_awake(self) -> None:
        """
        Called when the detector reports the driver is awake this frame.

        ACTIVE → POST_EVENT: record end time; keep recording for post_event_seconds
        POST_EVENT → no-op (countdown already running; push_frame() handles it)
        IDLE → no-op
        """
        if self._state == _State.ACTIVE:
            self._state = _State.POST_EVENT
            self.is_active = True   # still active (post-event in progress)
            self._ended_perf = time.perf_counter()
            self._ended_at_dt = datetime.now(timezone.utc)
            duration = round(self._ended_perf - self._start_perf, 2)
            print(f"[VigiDrive] Drowsiness ended; post-event tail started ({self.post_event_seconds}s)")
            print(f"[VigiDrive] Episode duration: {duration}s")

    def notify_no_face(self) -> None:
        """
        Called when no face is detected this frame.

        Treat the same as notify_awake(): transition ACTIVE→POST_EVENT.
        POST_EVENT remains as-is (countdown continues).
        """
        self.notify_awake()

    def finalize_now(self) -> Optional[Dict[str, Any]]:
        """
        Immediately finalize any in-progress recording (used on program termination).
        Safe to call at any time; returns the event dict or None.
        """
        if self._state in (_State.ACTIVE, _State.POST_EVENT):
            if self._state == _State.ACTIVE:
                # Record the end time now
                self._ended_perf = time.perf_counter()
                self._ended_at_dt = datetime.now(timezone.utc)
            return self._finalize()
        return None

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _update_fps_dims(self, frame: np.ndarray, fps: float) -> None:
        """Update cached fps/dimensions and (re)create pre-buffer if fps changed significantly."""
        h, w = frame.shape[:2]
        fps = max(1.0, fps)

        # Only recreate buffer if FPS changes significantly (>5 fps)
        # Minor fluctuations in FPS measurement should not destroy the buffer
        fps_changed_significantly = abs(fps - self._fps) > 5.0
        dims_changed = (w != self._width or h != self._height)

        if self._pre_buf is None or fps_changed_significantly:
            self._fps = fps
            self._pre_buf = RollingFrameBuffer(fps, self.pre_event_seconds)
        else:
            # Update FPS tracking without recreating buffer
            self._fps = fps

        if dims_changed:
            self._width = w
            self._height = h

    def _begin_episode(self) -> None:
        """Transition IDLE → ACTIVE: start recording with pre-buffer frames."""
        self._state = _State.ACTIVE
        self.is_active = True

        self._episode_id = f"vio_{uuid.uuid4().hex[:12]}"
        self._start_perf = time.perf_counter()
        self._started_at_dt = datetime.now(timezone.utc)

        # Compose MP4 filename
        ts = self._started_at_dt.strftime("%Y%m%d_%H%M%S")
        self._recording_path = self.recordings_dir / f"drowsiness_{ts}.mp4"
        counter = 1
        while self._recording_path.exists():
            self._recording_path = self.recordings_dir / f"drowsiness_{ts}_{counter}.mp4"
            counter += 1

        rel = self._relative_path(self._recording_path)
        print("[VigiDrive] Drowsiness episode started")
        print(f"[VigiDrive] Recording started: {rel}")

        # Open video writer
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        effective_fps = max(10.0, min(self._fps, 60.0))
        self._frames_written = 0
        self._frame_queue = queue.Queue(maxsize=_WRITER_QUEUE_MAXSIZE)
        self._video_writer = cv2.VideoWriter(
            str(self._recording_path),
            fourcc,
            effective_fps,
            (self._width, self._height),
        )

        self._writer_thread = threading.Thread(
            target=self._writer_worker,
            name="VigiDrive-VideoWriter",
            daemon=True,
        )
        self._writer_thread.start()

        # Drain pre-buffer: write buffered frames to MP4 first
        if self._pre_buf is not None:
            pre_frames = self._pre_buf.drain()
            pre_count = len(pre_frames)
            for f in pre_frames:
                self._enqueue_frame(f)
            print(f"[VigiDrive] Pre-event buffer flushed: {pre_count} frames (~{pre_count / max(1.0, self._fps):.1f}s)")

    def _enqueue_frame(self, frame: np.ndarray) -> None:
        """Enqueue frame for background writer; drop on overflow to protect main loop."""
        if self._frame_queue is None:
            return
        try:
            self._frame_queue.put_nowait(frame.copy())
        except queue.Full:
            pass  # Drop rather than block detection loop

    def _finalize(self) -> Optional[Dict[str, Any]]:
        """
        Finalize the recording: flush writer, save JSON event, reset state.
        Returns the event dict.
        """
        if self._state not in (_State.ACTIVE, _State.POST_EVENT):
            return None

        prev_state = self._state
        self._state = _State.IDLE
        self.is_active = False

        # Capture end time if not already set (e.g. finalize_now() from ACTIVE)
        ended_at_dt = self._ended_at_dt or datetime.now(timezone.utc)
        ended_perf = self._ended_perf if self._ended_perf > 0 else time.perf_counter()
        duration_seconds = round(ended_perf - self._start_perf, 2)

        # Stop background writer
        if self._frame_queue is not None:
            self._frame_queue.put(None)  # Sentinel
        if self._writer_thread is not None and self._writer_thread.is_alive():
            self._writer_thread.join(timeout=5.0)

        if self._video_writer is not None:
            self._video_writer.release()
            self._video_writer = None

        print("[VigiDrive] Drowsiness recording finalized")
        print(f"[VigiDrive] Duration: {duration_seconds}s")

        # Verify file
        recording_rel_path: Optional[str] = None
        if self._recording_path and self._recording_path.exists():
            size = self._recording_path.stat().st_size
            if size > 0:
                recording_rel_path = self._relative_path(self._recording_path)
                print(f"[VigiDrive] Recording saved: {recording_rel_path} ({size / 1024:.1f} KB)")
            else:
                try:
                    self._recording_path.unlink()
                except OSError:
                    pass
                print("[VigiDrive] Warning: Recording file was empty and removed.")
        else:
            print("[VigiDrive] Warning: Recording file was not generated.")

        # Build event
        event_data: Dict[str, Any] = {
            "eventId": self._episode_id,
            "type": "drowsiness",
            "startedAt": self._started_at_dt.isoformat() if self._started_at_dt else "",
            "endedAt": ended_at_dt.isoformat(),
            "durationSeconds": duration_seconds,
            "confidence": None,
            "systemId": self.system_id,
            "driverName": self.driver_name,
            "recordingPath": recording_rel_path,
            "resolved": False,
        }

        # Save JSON
        ts = (self._started_at_dt or ended_at_dt).strftime("%Y%m%d_%H%M%S")
        event_path = self.events_dir / f"drowsiness_{ts}.json"
        counter = 1
        while event_path.exists():
            event_path = self.events_dir / f"drowsiness_{ts}_{counter}.json"
            counter += 1

        try:
            with open(event_path, "w", encoding="utf-8") as fh:
                json.dump(event_data, fh, indent=2)
            print(f"[VigiDrive] Event saved: {self._relative_path(event_path)}")
        except Exception as exc:
            print(f"[VigiDrive] Error saving event JSON: {exc}")

        # Upload violation to Firestore (if violations client available)
        if self.violations_client:
            try:
                success = self.violations_client.create_violation(event_data)
                if success:
                    print(f"[VigiDrive] Violation uploaded to Firestore: {self._episode_id}")
            except Exception as exc:
                print(f"[VigiDrive] Firestore upload error (local event saved): {exc}")

        # Reset episode variables
        self._episode_id = None
        self._recording_path = None
        self._frame_queue = None
        self._writer_thread = None
        self._ended_perf = 0.0
        self._ended_at_dt = None

        # Reinitialise pre-buffer for next episode
        self._pre_buf = RollingFrameBuffer(self._fps, self.pre_event_seconds)

        return event_data

    def _writer_worker(self) -> None:
        """Background thread: encodes queued frames to MP4."""
        while True:
            try:
                frame = self._frame_queue.get()
                if frame is None:
                    self._frame_queue.task_done()
                    break
                if self._video_writer is not None:
                    self._video_writer.write(frame)
                    self._frames_written += 1
                self._frame_queue.task_done()
            except Exception:
                break

    def _relative_path(self, path: Path) -> str:
        try:
            return path.relative_to(self.project_root).as_posix()
        except ValueError:
            return path.as_posix()
