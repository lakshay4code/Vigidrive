"""
setup_device.py
===============
One-time device enrollment script for PC.

Exchanges email/password for Firebase refresh token and stores configuration locally.

Usage:
    python setup_device.py

The script will prompt for:
- Firebase email (device auth account)
- Firebase password (device auth account)
- System ID (Firestore document ID)

After successful setup, credentials are stored in .vigidrive/device_config.json
"""

import json
import sys
import getpass
from pathlib import Path

# Import Firebase Auth client
try:
    from src.firebase_auth import FirebaseAuthClient
except ModuleNotFoundError:
    sys.path.insert(0, str(Path(__file__).parent / "src"))
    from firebase_auth import FirebaseAuthClient


# Firebase configuration
FIREBASE_PROJECT_ID = "vigidrive-552c6"
FIREBASE_API_KEY = "AIzaSyBWykV_v9HFIIC3i6MEpU-igkpDps4XB5c"

# Configuration directory and file
CONFIG_DIR = Path.home() / ".vigidrive"
CONFIG_FILE = CONFIG_DIR / "device_config.json"


def main():
    print("=" * 60)
    print("VIGIDRIVE PC DEVICE SETUP")
    print("=" * 60)
    print()
    print("This script will set up Firebase authentication for your PC.")
    print("You need:")
    print("  1. A Firebase Auth account (email/password) for this device")
    print("  2. The System ID from your mobile app")
    print()

    # Check if already configured
    if CONFIG_FILE.exists():
        print(f"⚠️  Configuration already exists: {CONFIG_FILE}")
        overwrite = input("Overwrite existing configuration? (y/N): ").strip().lower()
        if overwrite != "y":
            print("Setup cancelled.")
            return

    # Prompt for credentials
    print()
    print("Enter device Firebase Auth credentials:")
    email = input("Email: ").strip()
    if not email:
        print("❌ Email is required")
        return

    password = getpass.getpass("Password: ")
    if not password:
        print("❌ Password is required")
        return

    print()
    system_id = input("System ID (from mobile app): ").strip()
    if not system_id:
        print("❌ System ID is required")
        return

    # Authenticate with Firebase
    print()
    print("🔐 Authenticating with Firebase...")
    try:
        auth_client = FirebaseAuthClient(FIREBASE_API_KEY)
        result = auth_client.sign_in_with_email_password(email, password)
        refresh_token = result.get("refreshToken")

        if not refresh_token:
            print("❌ Failed to obtain refresh token")
            return

        print("✅ Authentication successful")

    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        return

    # Create configuration directory
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    # Save configuration (refresh token only, no password)
    config = {
        "projectId": FIREBASE_PROJECT_ID,
        "apiKey": FIREBASE_API_KEY,
        "systemId": system_id,
        "refreshToken": refresh_token,
    }

    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)

        # Set file permissions (owner read/write only)
        CONFIG_FILE.chmod(0o600)

        print()
        print("✅ Configuration saved successfully")
        print(f"📁 Location: {CONFIG_FILE}")
        print()
        print("🚀 You can now run the detector:")
        print("   python src/webcam.py")

    except Exception as e:
        print(f"❌ Failed to save configuration: {e}")
        return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nSetup cancelled.")
        sys.exit(1)
