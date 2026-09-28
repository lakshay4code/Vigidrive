# Firebase Integration Setup Guide

## V1 PC-to-Firebase Integration

This guide describes how to set up Firebase authentication and heartbeat monitoring for the PC drowsiness detector.

---

## Prerequisites

1. **Firebase Console Access**
2. **Firebase Project**: `vigidrive-552c6`
3. **Python Environment**: Driver-Drowsiness-AI with dependencies installed

---

## Setup Steps

### 1. Create Device Firebase Auth Account

In Firebase Console → Authentication → Users:

1. Click "Add user"
2. Email: `lakshays-pc@vigidrive.local` (or any valid email format)
3. Password: Generate a strong password
4. Save the credentials securely
5. Note the **User UID** (e.g., `abc123def456...`)

### 2. Create System Document in Firestore

In Firebase Console → Firestore Database → systems collection:

1. Create document with ID: `lakshays-pc` (or your preferred system ID)
2. Add fields:
   ```
   ownerUid: <YOUR_MOBILE_USER_UID>
   deviceAuthUid: <PC_AUTH_USER_UID_FROM_STEP_1>
   systemName: "Lakshay's PC"
   status: "offline"
   lastHeartbeat: null
   createdAt: <server_timestamp>
   ```
3. Save the document

**Important:** 
- `ownerUid` = Your mobile app user UID (the person who owns this system)
- `deviceAuthUid` = The PC device's Firebase Auth UID from Step 1

### 3. Deploy Updated Firestore Rules

In Firebase Console → Firestore Database → Rules:

1. Copy the contents of `firestore.rules` from this repository
2. Paste into the Firebase Console rules editor
3. Click "Publish"

**Verify the rules include:**
- `isSystemDevice()` function
- `isHeartbeatOnlyUpdate()` function
- `protectedFieldsUnchanged()` function
- PC device update rule: `allow update: if isSystemDevice(systemId) && isHeartbeatOnlyUpdate();`

### 4. Run PC Device Setup

On your PC (where the detector runs):

```bash
cd Driver-Drowsiness-AI
python setup_device.py
```

When prompted, enter:
- **Email**: `lakshays-pc@vigidrive.local` (from Step 1)
- **Password**: The password you set in Step 1
- **System ID**: `lakshays-pc` (the Firestore document ID from Step 2)

The script will:
- Authenticate with Firebase
- Exchange credentials for a refresh token
- Store configuration in `~/.vigidrive/device_config.json`
- Set file permissions to owner-only (chmod 600)

### 5. Run the Detector

```bash
cd Driver-Drowsiness-AI
python src/webcam.py
```

You should see:
```
[Firebase] Authenticated successfully
[Firebase] Configured for system: lakshays-pc
[FirebaseHeartbeat] Started
[FirebaseHeartbeat] Heartbeat sent: lakshays-pc
```

The detector will:
- Set `status="online"` on startup
- Send heartbeat every 60 seconds (updates `lastHeartbeat`)
- Set `status="offline"` on clean shutdown
- Continue working locally if Firebase/network fails

---

## Verification

### Check Firebase Console

1. Go to Firestore Database → systems → `lakshays-pc`
2. Verify:
   - `status: "online"`
   - `lastHeartbeat: <recent timestamp>`

### Check Mobile App

1. Open VigiDrive mobile app
2. Navigate to Systems screen
3. Verify "Lakshay's PC" appears as ONLINE

---

## Troubleshooting

### "Authentication failed" during setup

- Verify email/password match Firebase Console
- Check internet connection
- Verify Firebase project ID in `setup_device.py` matches your project

### "Heartbeat failed: 403 Forbidden"

- Verify Firestore rules are deployed correctly
- Check `deviceAuthUid` in Firestore matches PC Auth UID
- Verify system document exists with ID matching `systemId` in config

### "No configuration found - running in offline mode"

- Run `setup_device.py` first
- Verify `~/.vigidrive/device_config.json` exists
- Check file permissions (should be readable)

### Detector runs but heartbeat fails silently

- Check console logs for `[FirebaseHeartbeat]` messages
- Verify internet connectivity
- Network failures are expected and don't crash the detector

---

## Security Notes

1. **No service account on PC** - Uses device-specific Firebase Auth identity
2. **Refresh token stored locally** - Password is never stored after setup
3. **Revocable access** - Delete PC Auth user or change `deviceAuthUid` to revoke
4. **Restricted writes** - PC can ONLY update `status` and `lastHeartbeat`
5. **Owner-protected** - Only mobile user can change `ownerUid`, `deviceAuthUid`, `systemName`

---

## Configuration File Structure

`~/.vigidrive/device_config.json`:
```json
{
  "projectId": "vigidrive-552c6",
  "apiKey": "AIzaSyBWykV_v9HFIIC3i6MEpU-igkpDps4XB5c",
  "systemId": "lakshays-pc",
  "refreshToken": "<long_token_string>"
}
```

**Never commit this file to git** - It's already in `.gitignore`

---

## Limitations (V1)

- Manual setup via Firebase Console (no mobile enrollment UI yet)
- No video upload
- No violation upload
- No automatic device discovery
- Single PC per system document

Future versions will add:
- Mobile app enrollment flow (QR code/device code)
- Automatic system creation
- Video upload to Firebase Storage
- Violation event upload to Firestore
