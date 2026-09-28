"""
firebase_violations.py
======================
Firestore REST API client for creating violation documents.

Handles:
- Creating violation documents in systems/{systemId}/violations/{violationId}
- Using device Firebase Auth credentials
- Network failure resilience (local events still saved)
"""

from typing import Dict, Any, Optional
from datetime import datetime, timezone

import requests

try:
    from src.firebase_auth import FirebaseAuthClient
except ModuleNotFoundError:
    from firebase_auth import FirebaseAuthClient


class FirebaseViolationsClient:
    """
    Manages violation document creation in Firestore for drowsiness episodes.

    Creates documents in: systems/{systemId}/violations/{violationId}
    """

    FIRESTORE_API_BASE = "https://firestore.googleapis.com/v1"

    def __init__(
        self,
        auth_client: FirebaseAuthClient,
        project_id: str,
        system_id: str,
    ):
        """
        Initialize violations client.

        Args:
            auth_client: Firebase Auth client for ID tokens
            project_id: Firebase project ID
            system_id: System document ID in Firestore
        """
        self.auth_client = auth_client
        self.project_id = project_id
        self.system_id = system_id

        # Firestore collection path
        self.collection_path = (
            f"projects/{project_id}/databases/(default)/documents/"
            f"systems/{system_id}/violations"
        )

    def create_violation(self, event_data: Dict[str, Any]) -> bool:
        """
        Create a violation document in Firestore from episode event data.

        Args:
            event_data: Event dictionary from VigiDriveEpisodeTracker._finalize()
                Required keys: eventId, type, startedAt, durationSeconds,
                              confidence, systemId, driverName, resolved
                Optional keys: recordingPath

        Returns:
            True if violation created successfully, False otherwise

        Network failures are logged but do not raise exceptions.
        """
        try:
            id_token = self.auth_client.get_valid_id_token()

            # Extract violation ID from eventId
            violation_id = event_data.get("eventId")
            if not violation_id:
                print("[FirebaseViolations] Error: Missing eventId in event_data")
                return False

            # Parse timestamp from startedAt ISO string (timezone-aware)
            started_at_str = event_data.get("startedAt", "")
            try:
                # Parse ISO 8601 timestamp (already UTC-aware from datetime.now(timezone.utc))
                timestamp_dt = datetime.fromisoformat(started_at_str)
                # Firestore expects RFC3339 format
                timestamp_iso = timestamp_dt.isoformat()
            except (ValueError, AttributeError):
                # Fallback to current UTC time if parsing fails
                timestamp_iso = datetime.now(timezone.utc).isoformat()
                print(f"[FirebaseViolations] Warning: Invalid startedAt timestamp, using current time")

            # Build Firestore document
            # Flutter ViolationModel expects:
            # - systemId (string)
            # - timestamp (Timestamp)
            # - type (string)
            # - durationSeconds (double)
            # - confidence (double, nullable)
            # - driverName (string)
            # - recordingPath (string, optional) - local path, not URL
            # - resolved (bool)
            body = {
                "fields": {
                    "systemId": {"stringValue": event_data.get("systemId", self.system_id)},
                    "timestamp": {"timestampValue": timestamp_iso},
                    "type": {"stringValue": event_data.get("type", "drowsiness")},
                    "durationSeconds": {"doubleValue": float(event_data.get("durationSeconds", 0.0))},
                    "driverName": {"stringValue": event_data.get("driverName", "")},
                    "resolved": {"booleanValue": event_data.get("resolved", False)},
                }
            }

            # Add confidence if not None (geometric EAR detector uses null)
            confidence = event_data.get("confidence")
            if confidence is not None:
                body["fields"]["confidence"] = {"doubleValue": float(confidence)}
            else:
                body["fields"]["confidence"] = {"nullValue": None}

            # Add recordingPath (local path reference, no upload yet)
            recording_path = event_data.get("recordingPath")
            if recording_path:
                body["fields"]["recordingPath"] = {"stringValue": recording_path}

            # Firestore REST API: Create document with specific ID
            url = f"{self.FIRESTORE_API_BASE}/{self.collection_path}"
            headers = {
                "Authorization": f"Bearer {id_token}",
                "Content-Type": "application/json",
            }

            # Use documentId parameter to set specific document ID
            params = {
                "documentId": violation_id,
            }

            response = requests.post(
                url,
                headers=headers,
                params=params,
                json=body,
                timeout=10,
            )

            if response.status_code == 200:
                print(f"[FirebaseViolations] Violation created: {violation_id}")
                return True
            else:
                print(
                    f"[FirebaseViolations] Violation creation failed: {response.status_code} - {response.text}"
                )
                return False

        except Exception as e:
            # Network failure or auth error - log and continue
            # Local JSON event is already saved by episode tracker
            print(f"[FirebaseViolations] Violation creation error (local event saved): {e}")
            return False
