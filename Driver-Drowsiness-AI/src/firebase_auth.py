"""
firebase_auth.py
================
Firebase Authentication REST API client for PC device.

Handles:
- Sign in with email/password
- Exchange email/password for refresh token (one-time setup)
- Refresh ID tokens from stored refresh token
- ID token lifecycle management
"""

import json
import time
from typing import Optional, Dict, Any
from pathlib import Path

import requests


class FirebaseAuthClient:
    """
    Firebase Auth REST API client for device authentication.

    Uses Firebase Identity Toolkit REST API to:
    1. Sign in with email/password
    2. Exchange credentials for refresh token
    3. Refresh ID tokens when expired
    """

    # Firebase Identity Toolkit REST API endpoints
    SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
    REFRESH_TOKEN_URL = "https://securetoken.googleapis.com/v1/token"

    # ID tokens expire in 1 hour; refresh proactively at 55 minutes
    TOKEN_EXPIRY_BUFFER_SECONDS = 300  # 5 minutes

    def __init__(self, api_key: str):
        """
        Initialize Firebase Auth client.

        Args:
            api_key: Firebase Web API key from firebase_options
        """
        self.api_key = api_key
        self._id_token: Optional[str] = None
        self._refresh_token: Optional[str] = None
        self._token_expiry_time: float = 0.0

    def sign_in_with_email_password(
        self,
        email: str,
        password: str
    ) -> Dict[str, Any]:
        """
        Sign in with email/password and obtain tokens.

        Args:
            email: Device Firebase Auth email
            password: Device Firebase Auth password

        Returns:
            Dict with idToken, refreshToken, expiresIn

        Raises:
            Exception: If sign-in fails
        """
        try:
            response = requests.post(
                self.SIGN_IN_URL,
                params={"key": self.api_key},
                json={
                    "email": email,
                    "password": password,
                    "returnSecureToken": True,
                },
                timeout=10,
            )
            response.raise_for_status()
            data = response.json()

            # Store tokens and expiry
            self._id_token = data["idToken"]
            self._refresh_token = data["refreshToken"]
            expires_in = int(data.get("expiresIn", 3600))
            self._token_expiry_time = time.time() + expires_in

            return data

        except requests.RequestException as e:
            raise Exception(f"Firebase sign-in failed: {e}")

    def refresh_id_token(self, refresh_token: Optional[str] = None) -> Dict[str, Any]:
        """
        Refresh ID token using refresh token.

        Args:
            refresh_token: Optional refresh token (uses stored if None)

        Returns:
            Dict with id_token, refresh_token, expires_in

        Raises:
            Exception: If token refresh fails
        """
        token = refresh_token or self._refresh_token
        if not token:
            raise Exception("No refresh token available")

        try:
            response = requests.post(
                self.REFRESH_TOKEN_URL,
                params={"key": self.api_key},
                json={
                    "grant_type": "refresh_token",
                    "refresh_token": token,
                },
                timeout=10,
            )
            response.raise_for_status()
            data = response.json()

            # Store new tokens and expiry
            self._id_token = data["id_token"]
            self._refresh_token = data["refresh_token"]
            expires_in = int(data.get("expires_in", 3600))
            self._token_expiry_time = time.time() + expires_in

            return data

        except requests.RequestException as e:
            raise Exception(f"Firebase token refresh failed: {e}")

    def get_valid_id_token(self) -> str:
        """
        Get a valid ID token, refreshing if necessary.

        Returns:
            Valid ID token string

        Raises:
            Exception: If no token available or refresh fails
        """
        # Check if token needs refresh
        time_until_expiry = self._token_expiry_time - time.time()

        if time_until_expiry < self.TOKEN_EXPIRY_BUFFER_SECONDS:
            # Token expired or about to expire - refresh it
            if not self._refresh_token:
                raise Exception("No refresh token available for renewal")
            self.refresh_id_token()

        if not self._id_token:
            raise Exception("No ID token available")

        return self._id_token

    @property
    def refresh_token(self) -> Optional[str]:
        """Get the current refresh token."""
        return self._refresh_token

    @refresh_token.setter
    def refresh_token(self, token: str) -> None:
        """Set the refresh token (for loading from config)."""
        self._refresh_token = token
        # Clear ID token to force refresh on next use
        self._id_token = None
        self._token_expiry_time = 0.0
