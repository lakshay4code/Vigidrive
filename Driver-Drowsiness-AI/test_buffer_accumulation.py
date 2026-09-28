"""
Test to verify that the rolling pre-buffer accumulates to full capacity
without being reset during normal awake operation.
"""
import numpy as np
from src.vigidrive_integration import VigiDriveEpisodeTracker

def test_buffer_accumulation():
    print("=" * 70)
    print("ROLLING BUFFER ACCUMULATION TEST")
    print("=" * 70)

    tracker = VigiDriveEpisodeTracker()
    dummy_frame = np.full((720, 1280, 3), 120, dtype=np.uint8)

    fps = 22.36  # Typical webcam FPS
    pre_event_seconds = 4.0
    expected_capacity = int(fps * pre_event_seconds)

    print(f"\nConfiguration:")
    print(f"  FPS: {fps}")
    print(f"  PRE_EVENT_SECONDS: {pre_event_seconds}")
    print(f"  Expected buffer capacity: {expected_capacity} frames")

    print(f"\n{'='*70}")
    print("PHASE 1: Accumulate frames while awake")
    print("="*70)

    # Push enough frames to fill buffer plus some extra
    total_frames = expected_capacity + 30
    print(f"Pushing {total_frames} frames at {fps} fps...")

    for i in range(total_frames):
        tracker.push_frame(dummy_frame, fps=fps)
        tracker.notify_awake()

    print(f"\n{'='*70}")
    print("VERIFICATION")
    print("="*70)

    if tracker._pre_buf is not None:
        actual_size = len(tracker._pre_buf)
        capacity = tracker._pre_buf.max_frames

        print(f"\nBuffer state after {total_frames} frames:")
        print(f"  Buffer capacity: {capacity} frames")
        print(f"  Actual buffered: {actual_size} frames")
        print(f"  Expected: ~{expected_capacity} frames")

        if actual_size == capacity:
            print(f"\n✅ SUCCESS: Buffer reached full capacity ({actual_size}/{capacity})")
        elif actual_size > capacity * 0.9:
            print(f"\n⚠️  PARTIAL: Buffer nearly full ({actual_size}/{capacity} = {100*actual_size/capacity:.1f}%)")
        else:
            print(f"\n❌ FAILURE: Buffer did not fill properly ({actual_size}/{capacity} = {100*actual_size/capacity:.1f}%)")

        # Verify no unexpected resets occurred
        if actual_size >= expected_capacity - 5:
            print(f"✅ No buffer resets detected during accumulation")
        else:
            print(f"❌ Buffer may have been reset (size too small)")

        return actual_size >= capacity * 0.9
    else:
        print("❌ FAILURE: Pre-buffer is None")
        return False

    print(f"\n{'='*70}")


if __name__ == "__main__":
    success = test_buffer_accumulation()
    exit(0 if success else 1)
