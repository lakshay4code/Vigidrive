"""
test_offline_status.py
======================
Test script to verify offline status is correctly written to Firestore.

Simulates the detector shutdown sequence and verifies the Firestore document state.
"""

import json
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from firebase_auth import FirebaseAuthClient
from firebase_heartbeat import FirebaseHeartbeatManager


def main():
    print("=" * 60)
    print("OFFLINE STATUS TEST")
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

    # Initialize heartbeat manager
    print("\n2. Initializing heartbeat manager...")
    heartbeat_manager = FirebaseHeartbeatManager(
        auth_client=auth_client,
        project_id=project_id,
        system_id=system_id,
    )

    # Send online heartbeat
    print("\n3. Sending ONLINE heartbeat...")
    heartbeat_manager._send_heartbeat()

    # Wait a moment
    import time
    time.sleep(2)

    # Send offline status
    print("\n4. Sending OFFLINE status...")
    heartbeat_manager._send_offline_status()

    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)
    print("\nCheck the output above to verify:")
    print("  - Heartbeat sent successfully")
    print("  - Offline status sent successfully")
    print("  - Verified document state shows:")
    print("    isOnline: False")
    print("    isConnected: False")
    print("    connectionStatus: INACTIVE")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nTest cancelled.")
        sys.exit(1)
