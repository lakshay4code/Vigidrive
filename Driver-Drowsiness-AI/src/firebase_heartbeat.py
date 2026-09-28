"""
firebase_heartbeat.py
=====================
Background heartbeat manager for PC device status updates to Firestore.

Manages:
- Background thread for periodic heartbeat updates
- Firestore REST API updates (status, lastHeartbeat)
- Network failure resilience (continues locally if Firebase fails)
- Graceful shutdown with offline status update
"""

import json
import threading
import time
from typing import Optional
from datetime import datetime

import requests

try:
    from src.firebase_auth import FirebaseAuthClient
except ModuleNotFoundError:
    from firebase_auth import FirebaseAuthClient


class FirebaseHeartbeatManager:
    """
    Manages periodic heartbeat updates to Firestore for device status.

    Runs a background thread that:
    - Updates systems/{systemId} every 60 seconds
    - Sets status="online" and lastHeartbeat=serverTimestamp()
    - Handles network failures gracefully (logs and continues)
    - Sets status="offline" on shutdown
    """

    HEARTBEAT_INTERVAL_SECONDS = 60
    FIRESTORE_API_BASE = "https://firestore.googleapis.com/v1"

    def __init__(
        self,
        auth_client: FirebaseAuthClient,
        project_id: str,
        system_id: str,
    ):
        """
        Initialize heartbeat manager.

        Args:
            auth_client: Firebase Auth client for ID tokens
            project_id: Firebase project ID
            system_id: System document ID in Firestore
        """
        self.auth_client = auth_client
        self.project_id = project_id
        self.system_id = system_id

        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()

        # Firestore document path
        self.document_path = (
            f"projects/{project_id}/databases/(default)/documents/systems/{system_id}"
        )

    def start(self) -> None:
        """Start the background heartbeat thread."""
        if self._running:
            print("[FirebaseHeartbeat] Already running")
            return

        self._running = True
        self._stop_event.clear()

        # Send initial online status immediately
        self._send_heartbeat()

        # Start background thread
        self._thread = threading.Thread(
            target=self._heartbeat_loop,
            name="FirebaseHeartbeat",
            daemon=True,
        )
        self._thread.start()
        print("[FirebaseHeartbeat] Started")

    def stop(self, timeout: float = 5.0) -> None:
        """
        Stop the heartbeat thread and set offline status.

        Args:
            timeout: Maximum seconds to wait for thread to stop
        """
        if not self._running:
            return

        print("[FirebaseHeartbeat] Stopping...")
        self._running = False
        self._stop_event.set()

        # Wait for thread to finish
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=timeout)

        # Send final offline status (best-effort)
        self._send_offline_status()
        print("[FirebaseHeartbeat] Stopped")

    def _heartbeat_loop(self) -> None:
        """Background thread loop - sends heartbeat every 60 seconds."""
        while self._running:
            # Wait for interval or stop event
            if self._stop_event.wait(timeout=self.HEARTBEAT_INTERVAL_SECONDS):
                break  # Stop event was set

            # Send heartbeat
            self._send_heartbeat()

    def _send_heartbeat(self) -> None:
        """
        Send heartbeat update to Firestore (isOnline=true, isConnected=true, connectionStatus=ACTIVE, lastHeartbeat=now).

        Network failures are logged but do not crash the detector.
        """
        try:
            id_token = self.auth_client.get_valid_id_token()

            # Firestore REST API PATCH request
            url = self.document_path
            headers = {
                "Authorization": f"Bearer {id_token}",
                "Content-Type": "application/json",
            }

            # Update fields that Flutter SystemModel reads: isOnline, isConnected, connectionStatus
            body = {
                "fields": {
                    "isOnline": {"booleanValue": True},
                    "isConnected": {"booleanValue": True},
                    "connectionStatus": {"stringValue": "ACTIVE"},
                    "lastHeartbeat": {"timestampValue": datetime.utcnow().isoformat() + "Z"},
                }
            }

            # Specify which fields to update (prevents accidental overwrites)
            params = [
                ("updateMask.fieldPaths", "isOnline"),
                ("updateMask.fieldPaths", "isConnected"),
                ("updateMask.fieldPaths", "connectionStatus"),
                ("updateMask.fieldPaths", "lastHeartbeat"),
            ]

            response = requests.patch(
                f"{self.FIRESTORE_API_BASE}/{url}",
                headers=headers,
                params=params,
                json=body,
                timeout=10,
            )

            if response.status_code == 200:
                print(f"[FirebaseHeartbeat] Heartbeat sent: {self.system_id}")
            else:
                print(
                    f"[FirebaseHeartbeat] Heartbeat failed: {response.status_code} - {response.text}"
                )

        except Exception as e:
            # Network failure or auth error - log and continue
            print(f"[FirebaseHeartbeat] Heartbeat error (detector continues): {e}")

    def _send_offline_status(self) -> None:
        """
        Send offline status to Firestore on shutdown (best-effort).

        If this fails, the mobile app will detect offline via heartbeat timeout.
        """
        try:
            id_token = self.auth_client.get_valid_id_token()

            url = self.document_path
            headers = {
                "Authorization": f"Bearer {id_token}",
                "Content-Type": "application/json",
            }

            body = {
                "fields": {
                    "isOnline": {"booleanValue": False},
                    "isConnected": {"booleanValue": False},
                    "connectionStatus": {"stringValue": "INACTIVE"},
                }
            }

            # Use list of tuples to support multiple updateMask.fieldPaths parameters
            params = [
                ("updateMask.fieldPaths", "isOnline"),
                ("updateMask.fieldPaths", "isConnected"),
                ("updateMask.fieldPaths", "connectionStatus"),
            ]

            response = requests.patch(
                f"{self.FIRESTORE_API_BASE}/{url}",
                headers=headers,
                params=params,
                json=body,
                timeout=5,
            )

            if response.status_code == 200:
                print(f"[FirebaseHeartbeat] Offline status sent: {self.system_id}")
                print(f"[FirebaseHeartbeat] PATCH response: {response.status_code}")

                # Verify the document was actually updated by reading it back
                try:
                    verify_response = requests.get(
                        f"{self.FIRESTORE_API_BASE}/{url}",
                        headers=headers,
                        timeout=3,
                    )
                    if verify_response.status_code == 200:
                        doc_data = verify_response.json()
                        fields = doc_data.get("fields", {})
                        is_online = fields.get("isOnline", {}).get("booleanValue")
                        is_connected = fields.get("isConnected", {}).get("booleanValue")
                        conn_status = fields.get("connectionStatus", {}).get("stringValue")
                        last_hb = fields.get("lastHeartbeat", {}).get("timestampValue")

                        print(f"[FirebaseHeartbeat] Verified document state:")
                        print(f"  isOnline: {is_online}")
                        print(f"  isConnected: {is_connected}")
                        print(f"  connectionStatus: {conn_status}")
                        print(f"  lastHeartbeat: {last_hb}")
                except Exception as verify_error:
                    print(f"[FirebaseHeartbeat] Verification read failed: {verify_error}")
            else:
                print(
                    f"[FirebaseHeartbeat] Offline status failed: {response.status_code} - {response.text}"
                )

        except Exception as e:
            # Best-effort only - app will detect offline via heartbeat timeout
            print(f"[FirebaseHeartbeat] Offline status error (expected on crash): {e}")
