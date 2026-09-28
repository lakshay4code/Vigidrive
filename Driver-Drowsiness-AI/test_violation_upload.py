"""
test_violation_upload.py
=========================
Test script to verify Firestore violation creation from drowsiness events.

Simulates a drowsiness episode and verifies the violation document is created in Firestore.
"""

import json
import sys
from pathlib import Path
from datetime import datetime

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from firebase_auth import FirebaseAuthClient
from firebase_violations import FirebaseViolationsClient


def main():
    print("=" * 60)
    print("FIRESTORE VIOLATION UPLOAD TEST")
    print("=" * 60)

    # Load config
    config_file = Path.home() / ".vigidrive" / "device_config.json"
    if not config_file.exists():
        print("❌ No device configuration found")
        print("Run setup_device.py first")
        return

    with open(config_file, "r") as f:
        config = json.load(f)

    project_id = config["projectId"]
    api_key = config["apiKey"]
    system_id = config["systemId"]
    refresh_token = config["refreshToken"]

    print(f"\nSystem ID: {system_id}")
    print(f"Project ID: {project_id}")

    # Initialize Firebase Auth
    print("\n1. Authenticating...")
    auth_client = FirebaseAuthClient(api_key)
    auth_client.refresh_token = refresh_token

    try:
        auth_client.get_valid_id_token()
        print("✅ Authentication successful")
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        return

    # Initialize violations client
    print("\n2. Initializing violations client...")
    violations_client = FirebaseViolationsClient(
        auth_client=auth_client,
        project_id=project_id,
        system_id=system_id,
    )

    # Create test event data (matches VigiDriveEpisodeTracker output)
    print("\n3. Creating test violation event...")
    test_event = {
        "eventId": f"vio_test_{int(datetime.now().timestamp())}",
        "type": "drowsiness",
        "startedAt": datetime.now().isoformat() + "Z",
        "endedAt": datetime.now().isoformat() + "Z",
        "durationSeconds": 5.2,
        "confidence": None,  # EAR detector uses null
        "systemId": system_id,
        "driverName": "Test Driver",
        "recordingPath": "recordings/test_20260927_143503.mp4",
        "resolved": False,
    }

    print(f"Event ID: {test_event['eventId']}")
    print(f"Duration: {test_event['durationSeconds']}s")
    print(f"Confidence: {test_event['confidence']}")

    # Upload violation
    print("\n4. Uploading violation to Firestore...")
    success = violations_client.create_violation(test_event)

    if success:
        print("✅ Violation created successfully")
        print(f"\nFirestore path:")
        print(f"  systems/{system_id}/violations/{test_event['eventId']}")
    else:
        print("❌ Violation creation failed")
        return

    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)
    print("\nVerify in Firebase Console:")
    print(f"  Firestore > systems > {system_id} > violations")
    print(f"  Document ID: {test_event['eventId']}")
    print("\nExpected fields:")
    print("  - systemId: string")
    print("  - timestamp: timestamp")
    print("  - type: 'drowsiness'")
    print("  - durationSeconds: 5.2")
    print("  - confidence: null")
    print("  - driverName: 'Test Driver'")
    print("  - recordingUrl: 'recordings/test_20260927_143503.mp4'")
    print("  - resolved: false")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nTest cancelled.")
        sys.exit(1)
