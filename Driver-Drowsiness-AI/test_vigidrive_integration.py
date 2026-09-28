import os
import time
import json
import tempfile
import shutil
from pathlib import Path
import numpy as np

from src.vigidrive_integration import VigiDriveEpisodeTracker


def run_tests():
    print("==================================================")
    print("VigiDrive Local Integration Tests")
    print("==================================================")

    # Create a temporary test directory to avoid permission issues
    test_dir = Path(tempfile.mkdtemp(prefix="vigidrive_test_"))

    try:
        tracker = VigiDriveEpisodeTracker(
            system_id="LakshaysPC",
            driver_name="Lakshay",
            project_root=test_dir
        )

        dummy_frame = np.full((720, 1280, 3), 120, dtype=np.uint8)

        # -----------------------------------------------------------------
        # Test A: Normal Awake Operation (no sleepy state)
        # -----------------------------------------------------------------
        print("\n--- Test A: Normal Awake Operation ---")
        # Simulate 10 awake frames - should maintain pre-buffer but not record
        for _ in range(10):
            tracker.push_frame(dummy_frame, fps=30.0)
            tracker.notify_awake()

        assert not tracker.is_active, "Tracker must be inactive in Awake state"
        assert len(list(tracker.recordings_dir.glob("*"))) == 0, "No recordings should exist in Awake state"
        assert len(list(tracker.events_dir.glob("*"))) == 0, "No events should exist in Awake state"
        print("[PASS] Test A: No recording or event created during Awake operation.")

        # -----------------------------------------------------------------
        # Test B: Confirmed Sleepy Episode (Episode starts)
        # -----------------------------------------------------------------
        print("\n--- Test B: Confirmed Sleepy Episode ---")
        # Simulate drowsiness confirmation
        for _ in range(15):
            tracker.push_frame(dummy_frame, fps=30.0)
            tracker.notify_sleepy()

        assert tracker.is_active, "Tracker must be active after drowsiness confirmed"
        active_files_start = list(tracker.recordings_dir.glob("*"))
        assert len(active_files_start) == 1, "Exactly ONE recording file should be created upon episode start"
        print("[PASS] Test B: Exactly one recording started upon drowsiness confirmation.")

        # -----------------------------------------------------------------
        # Test C: Continued Sleepy Frames (No duplicate events or recordings)
        # -----------------------------------------------------------------
        print("\n--- Test C: Continued Sleepy Frames ---")
        for _ in range(50):
            tracker.push_frame(dummy_frame, fps=30.0)
            tracker.notify_sleepy()

        assert tracker.is_active, "Tracker must remain active while sleepy"
        active_files_cont = list(tracker.recordings_dir.glob("*"))
        assert len(active_files_cont) == 1, f"Expected 1 recording file during continuous episode, got {len(active_files_cont)}"
        print("[PASS] Test C: 50 continuous sleepy frames produced no duplicate recordings or events.")

        # -----------------------------------------------------------------
        # Test D: Return to Awake (Episode finalized)
        # -----------------------------------------------------------------
        print("\n--- Test D: Return to Awake ---")
        time.sleep(0.3)

        # Transition to awake - triggers POST_EVENT state
        tracker.push_frame(dummy_frame, fps=30.0)
        tracker.notify_awake()

        # Continue pushing frames during post-event period
        for _ in range(90):  # ~3 seconds at 30fps
            tracker.push_frame(dummy_frame, fps=30.0)
            time.sleep(0.033)  # ~30fps timing

        # Wait a bit more to ensure finalization
        time.sleep(0.2)

        assert not tracker.is_active, "Tracker must be inactive after post-event period"
        events_saved = list(tracker.events_dir.glob("*.json"))
        assert len(events_saved) == 1, f"Expected 1 event JSON, found {len(events_saved)}"

        # Check JSON structure
        with open(events_saved[0], "r", encoding="utf-8") as f:
            event1 = json.load(f)

        assert event1["type"] == "drowsiness"
        assert event1["systemId"] == "LakshaysPC"
        assert event1["driverName"] == "Lakshay"
        assert event1["confidence"] is None
        assert event1["durationSeconds"] >= 0.3, f"Duration should be >= 0.3s, got {event1['durationSeconds']}"
        assert event1["recordingPath"] is not None, "Recording path must be present"

        rec_file = Path(tracker.project_root / event1["recordingPath"])
        assert rec_file.exists(), "Recording file must exist"
        assert rec_file.stat().st_size > 0, "Recording file must have non-zero size"

        print(f"[PASS] Test D: Episode finalized. Duration: {event1['durationSeconds']}s, File size: {rec_file.stat().st_size} bytes")

        # -----------------------------------------------------------------
        # Test E: Next Separate Drowsiness Episode (Separate event & recording)
        # -----------------------------------------------------------------
        print("\n--- Test E: Next Separate Drowsiness Episode ---")
        time.sleep(0.1)

        # Start second episode
        for _ in range(16):
            tracker.push_frame(dummy_frame, fps=30.0)
            tracker.notify_sleepy()

        assert tracker.is_active, "Tracker must be active for episode 2"
        assert len(list(tracker.recordings_dir.glob("*"))) == 2, "Second episode must create a distinct second recording"

        time.sleep(0.2)

        # End second episode
        tracker.push_frame(dummy_frame, fps=30.0)
        tracker.notify_awake()

        # Post-event frames
        for _ in range(90):
            tracker.push_frame(dummy_frame, fps=30.0)
            time.sleep(0.033)

        time.sleep(0.2)

        assert not tracker.is_active, "Tracker must be inactive after episode 2"
        events_saved = list(tracker.events_dir.glob("*.json"))
        assert len(events_saved) == 2, f"Expected 2 event JSON files, found {len(events_saved)}"

        # Load both events
        event_files = sorted(events_saved)
        with open(event_files[1], "r", encoding="utf-8") as f:
            event2 = json.load(f)

        assert event2["eventId"] != event1["eventId"], "Event IDs must be unique"
        assert event2["recordingPath"] != event1["recordingPath"], "Recording paths must be unique"
        assert len(list(tracker.recordings_dir.glob("*"))) == 2, "Exactly 2 recording files must exist"

        print(f"[PASS] Test E: Second separate episode created distinct event: {event2['eventId']} and recording: {event2['recordingPath']}")

        print("\n==================================================")
        print("ALL INTEGRATION TESTS PASSED SUCCESSFULLY!")
        print("==================================================")

    finally:
        # Clean up temporary test directory
        try:
            shutil.rmtree(test_dir)
        except Exception as e:
            print(f"Warning: Could not clean up test directory: {e}")


if __name__ == "__main__":
    run_tests()
