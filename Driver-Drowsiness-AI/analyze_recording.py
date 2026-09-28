"""
Diagnostic script to analyze VigiDrive recording behavior.
Measures actual frame counts, timing, and identifies discrepancies.
"""
import time
import numpy as np
from pathlib import Path
from src.vigidrive_integration import VigiDriveEpisodeTracker

def analyze_recording_pipeline():
    print("=" * 70)
    print("VIGIDRIVE RECORDING PIPELINE ANALYSIS")
    print("=" * 70)

    tracker = VigiDriveEpisodeTracker()
    dummy_frame = np.full((720, 1280, 3), 120, dtype=np.uint8)

    # Configuration
    fps = 30.0
    pre_event_seconds = 4.0
    post_event_seconds = 2.0

    print(f"\nConfiguration:")
    print(f"  PRE_EVENT_SECONDS: {tracker.pre_event_seconds}")
    print(f"  POST_EVENT_SECONDS: {tracker.post_event_seconds}")
    print(f"  Test FPS: {fps}")

    # Calculate expected frame counts
    expected_pre_frames = int(fps * pre_event_seconds)
    expected_post_frames = int(fps * post_event_seconds)

    print(f"\nExpected Frame Counts:")
    print(f"  Pre-event buffer capacity: {expected_pre_frames} frames ({pre_event_seconds}s)")
    print(f"  Post-event recording: {expected_post_frames} frames ({post_event_seconds}s)")

    # Phase 1: Build pre-buffer
    print(f"\n{'='*70}")
    print("PHASE 1: Building Pre-Event Buffer (Awake State)")
    print("="*70)

    awake_frames = 150  # 5 seconds at 30fps
    print(f"Pushing {awake_frames} frames at {fps} fps (~{awake_frames/fps:.1f}s)...")

    for i in range(awake_frames):
        tracker.push_frame(dummy_frame, fps=fps)
        tracker.notify_awake()

    # Check buffer state
    if tracker._pre_buf is not None:
        actual_buffered = len(tracker._pre_buf)
        buffer_capacity = tracker._pre_buf.max_frames
        print(f"\nPre-buffer state:")
        print(f"  Capacity: {buffer_capacity} frames")
        print(f"  Actually buffered: {actual_buffered} frames (~{actual_buffered/fps:.2f}s)")
        print(f"  Fill ratio: {actual_buffered}/{buffer_capacity} = {100*actual_buffered/buffer_capacity:.1f}%")

        if actual_buffered < buffer_capacity:
            print(f"  ⚠️  WARNING: Buffer not full! Missing {buffer_capacity - actual_buffered} frames")

    # Phase 2: Drowsiness episode
    print(f"\n{'='*70}")
    print("PHASE 2: Drowsiness Episode (Active State)")
    print("="*70)

    episode_frames = 60  # 2 seconds at 30fps
    print(f"Simulating drowsiness for {episode_frames} frames (~{episode_frames/fps:.1f}s)...")

    episode_start_time = time.perf_counter()

    for i in range(episode_frames):
        tracker.push_frame(dummy_frame, fps=fps)
        tracker.notify_sleepy()

    episode_duration = time.perf_counter() - episode_start_time
    print(f"Episode simulation took {episode_duration:.2f}s real time")
    print(f"Tracker state: {'ACTIVE' if tracker.is_active else 'IDLE'}")

    # Phase 3: Return to awake (post-event)
    print(f"\n{'='*70}")
    print("PHASE 3: Post-Event Recording (Awake Again)")
    print("="*70)

    print(f"Transitioning to awake (triggers POST_EVENT state)...")
    tracker.push_frame(dummy_frame, fps=fps)
    tracker.notify_awake()

    print(f"Pushing {expected_post_frames} post-event frames...")
    post_start = time.perf_counter()

    for i in range(expected_post_frames):
        tracker.push_frame(dummy_frame, fps=fps)
        time.sleep(1.0 / fps)  # Simulate real-time frame rate

    post_elapsed = time.perf_counter() - post_start
    print(f"Post-event period: {post_elapsed:.2f}s elapsed")
    print(f"Should finalize after ~{post_event_seconds}s")

    # Wait for finalization
    time.sleep(0.5)

    # Check if finalized
    print(f"\nTracker state after post-event: {'ACTIVE' if tracker.is_active else 'IDLE'}")

    if tracker.is_active:
        print("⚠️  Tracker still active - manually finalizing...")
        event = tracker.finalize_now()

    # Phase 4: Analyze results
    print(f"\n{'='*70}")
    print("PHASE 4: Recording Analysis")
    print("="*70)

    recordings = list(tracker.recordings_dir.glob("*.mp4"))
    events = list(tracker.events_dir.glob("*.json"))

    print(f"\nFiles created:")
    print(f"  Recordings: {len(recordings)}")
    print(f"  Events: {len(events)}")

    if recordings:
        import cv2
        for rec_path in recordings:
            print(f"\n  Analyzing: {rec_path.name}")

            cap = cv2.VideoCapture(str(rec_path))

            if cap.isOpened():
                actual_frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                recorded_fps = cap.get(cv2.CAP_PROP_FPS)
                recorded_duration = cap.get(cv2.CAP_PROP_FRAME_COUNT) / recorded_fps if recorded_fps > 0 else 0
                width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                file_size = rec_path.stat().st_size / 1024  # KB

                print(f"    Frame count: {actual_frame_count} frames")
                print(f"    Recorded FPS: {recorded_fps}")
                print(f"    Duration: {recorded_duration:.2f}s")
                print(f"    Resolution: {width}x{height}")
                print(f"    File size: {file_size:.1f} KB")

                # Expected totals
                expected_total_frames = expected_pre_frames + episode_frames + expected_post_frames
                expected_duration = expected_total_frames / fps

                print(f"\n    Expected vs Actual:")
                print(f"      Pre-buffer:  {expected_pre_frames} frames ({pre_event_seconds}s)")
                print(f"      Episode:     {episode_frames} frames ({episode_frames/fps:.1f}s)")
                print(f"      Post-event:  {expected_post_frames} frames ({post_event_seconds}s)")
                print(f"      ---")
                print(f"      Total expected: {expected_total_frames} frames ({expected_duration:.1f}s)")
                print(f"      Total actual:   {actual_frame_count} frames ({recorded_duration:.2f}s)")
                print(f"      Difference:     {actual_frame_count - expected_total_frames} frames ({recorded_duration - expected_duration:.2f}s)")

                if actual_frame_count < expected_total_frames:
                    missing = expected_total_frames - actual_frame_count
                    print(f"\n    ❌ DISCREPANCY: Missing {missing} frames ({missing/fps:.2f}s)")

                    # Diagnose where frames were lost
                    if actual_buffered < expected_pre_frames:
                        print(f"       - Pre-buffer was not full: {actual_buffered}/{expected_pre_frames} frames")

                    estimated_active_post = actual_frame_count - actual_buffered
                    expected_active_post = episode_frames + expected_post_frames

                    if estimated_active_post < expected_active_post:
                        print(f"       - Active/post frames short: ~{estimated_active_post} vs {expected_active_post} expected")

                cap.release()

    # Cleanup
    print(f"\nCleaning up test files...")
    for f in recordings + events:
        try:
            f.unlink()
        except:
            pass

    print(f"\n{'='*70}")
    print("ANALYSIS COMPLETE")
    print("="*70)

if __name__ == "__main__":
    analyze_recording_pipeline()
