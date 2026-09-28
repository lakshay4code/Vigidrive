# VigiDrive

**Real-time Driver Drowsiness Monitoring System**

A production-ready driver safety monitoring system integrating a PC-based drowsiness detector with a Flutter mobile application through Firebase/Firestore.

---

## Overview

VigiDrive is a real-time monitoring platform that detects driver drowsiness using computer vision on a monitoring PC and syncs violation events to a mobile Android app via Firebase. The system provides instant alerts when drowsiness is detected and maintains a synchronized record of all safety violations.

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      VIGIDRIVE SYSTEM                            │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐
│   Monitoring PC      │         │   Firebase/Firestore │
│                      │         │                      │
│  ┌───────────────┐   │         │  ┌───────────────┐   │
│  │  Webcam Feed  │   │         │  │   Systems     │   │
│  └───────┬───────┘   │         │  │  Collection   │   │
│          │           │         │  └───────────────┘   │
│          ▼           │         │                      │
│  ┌───────────────┐   │         │  ┌───────────────┐   │
│  │   MediaPipe   │   │  HTTP   │  │  Violations   │   │
│  │  EAR Detector │───┼────────▶│  │ Subcollection │   │
│  └───────────────┘   │ REST API│  └───────────────┘   │
│          │           │         │                      │
│          ▼           │         │  ┌───────────────┐   │
│  ┌───────────────┐   │         │  │   Heartbeat   │   │
│  │MP4 Recording  │   │  AUTH   │  │    (30s)      │   │
│  │  + Alarm      │   │◀────────│  └───────────────┘   │
│  └───────────────┘   │         │                      │
│                      │         │                      │
│  Local Storage:      │         └──────────┬───────────┘
│  • recordings/*.mp4  │                    │
│  • events/*.json     │                    │ Real-time
└──────────────────────┘                    │ Sync
                                            │
                                            ▼
                              ┌──────────────────────┐
                              │  Android Mobile App  │
                              │     (Flutter)        │
                              │                      │
                              │  ┌───────────────┐   │
                              │  │  Home Screen  │   │
                              │  │  - Welcome    │   │
                              │  │  - Monitoring │   │
                              │  │  - Activity   │   │
                              │  └───────────────┘   │
                              │                      │
                              │  ┌───────────────┐   │
                              │  │ My Systems    │   │
                              │  │  - Status     │   │
                              │  │  - Violations │   │
                              │  └───────────────┘   │
                              │                      │
                              │  ┌───────────────┐   │
                              │  │ Notifications │   │
                              │  │  - Unresolved │   │
                              │  │  - Alerts     │   │
                              │  └───────────────┘   │
                              └──────────────────────┘
```

---

## Features

### PC Detector (Python)
- ✅ Real-time drowsiness detection using MediaPipe Face Mesh
- ✅ Eye Aspect Ratio (EAR) calculation for drowsiness detection
- ✅ Configurable thresholds and episode tracking
- ✅ Local MP4 recording (4-second pre-event buffer + full episode + 3-second tail)
- ✅ Audio alarm on detection
- ✅ Automatic Firebase violation creation via REST API
- ✅ 30-second heartbeat to Firebase (online/offline status)
- ✅ Local event JSON backup

### Mobile App (Flutter/Android)
- ✅ Real-time violation monitoring via Firestore streams
- ✅ System status tracking (online/offline)
- ✅ Violation details with timestamp, duration, driver info
- ✅ Notifications for unresolved violations
- ✅ Firebase Authentication
- ✅ Professional, institutional UI design
- ✅ Honest recording status (local PC storage, not cloud)

### Firebase Integration
- ✅ Firestore database for violations and systems
- ✅ Firebase Authentication for mobile users
- ✅ Secure Firestore rules (PC device auth, mobile owner access)
- ✅ Real-time synchronization
- ✅ RESTful violation creation from PC

---

## Technology Stack

### PC Detector
- **Language:** Python 3.10+
- **Computer Vision:** MediaPipe (Face Mesh)
- **Video:** OpenCV (cv2)
- **Recording:** MP4 (cv2.VideoWriter, H.264)
- **Audio:** winsound (Windows alarm)
- **Firebase:** REST API (requests library)
- **Authentication:** Firebase Auth (device credentials)

### Mobile App
- **Framework:** Flutter 3.x
- **Language:** Dart
- **Database:** Cloud Firestore
- **Authentication:** Firebase Auth
- **Platform:** Android
- **UI:** Material Design 3, custom professional theme

### Backend
- **Database:** Cloud Firestore
- **Authentication:** Firebase Authentication
- **Security:** Firestore Security Rules
- **Hosting:** Firebase (optional, for rules deployment)

---

## Project Structure

```
vigidrive/
├── lib/                          # Flutter app source
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_strings.dart
│   │   ├── firebase/
│   │   │   └── firebase_service.dart
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_typography.dart
│   │       └── app_theme.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── models/
│   │   │   ├── presentation/
│   │   │   ├── services/
│   │   │   └── widgets/
│   │   ├── home/
│   │   │   └── presentation/
│   │   ├── notifications/
│   │   │   └── presentation/
│   │   ├── recordings/
│   │   │   └── presentation/
│   │   ├── settings/
│   │   │   └── presentation/
│   │   ├── shell/
│   │   │   └── main_shell.dart
│   │   ├── systems/
│   │   │   ├── models/
│   │   │   ├── presentation/
│   │   │   ├── services/
│   │   │   └── widgets/
│   │   └── violations/
│   │       ├── models/
│   │       ├── presentation/
│   │       ├── services/
│   │       └── widgets/
│   └── main.dart
│
├── Driver-Drowsiness-AI/         # PC detector
│   ├── src/
│   │   ├── drowsiness_detector.py
│   │   ├── episode_tracker.py
│   │   ├── firebase_auth.py
│   │   ├── firebase_heartbeat.py
│   │   ├── firebase_violations.py
│   │   └── face_mesh_detector.py
│   ├── main.py                   # Entry point
│   ├── requirements.txt
│   ├── alarm.wav
│   ├── recordings/               # Local MP4 storage (gitignored)
│   └── events/                   # Local JSON backup (gitignored)
│
├── android/                      # Android project
├── test/                         # Flutter tests
├── assets/                       # App assets
├── firestore.rules               # Firestore security rules
├── storage.rules                 # Firebase Storage rules (unused)
├── firebase.json                 # Firebase config
├── .firebaserc                   # Firebase project
├── pubspec.yaml                  # Flutter dependencies
└── README.md                     # This file
```

---

## Getting Started

### Prerequisites

1. **Python 3.10+** (for PC detector)
2. **Flutter SDK 3.x** (for mobile app)
3. **Android Studio** (for mobile development)
4. **Firebase Project** (with Firestore enabled)
5. **Webcam** (for PC detector)

### Firebase Setup

1. Create a Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/)

2. Enable **Firestore Database**
   - Start in production mode
   - Choose a location

3. Enable **Firebase Authentication**
   - Enable Email/Password authentication

4. Create a system document in Firestore:
   ```
   systems/{systemId}
   ├── deviceAuthUid: "device-auth-uid-here"
   ├── ownerUid: "mobile-user-uid-here"
   ├── name: "Monitoring System 1"
   ├── driverName: "Driver Name"
   ├── driverPhone: "+1234567890" (optional)
   ├── isConnected: false
   ├── isOnline: false
   ├── connectionStatus: "offline"
   ├── lastHeartbeat: null
   └── hasUnresolvedViolations: false
   ```

5. Deploy Firestore Security Rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

6. Download configuration:
   - **Android:** Download `google-services.json` → `android/app/`
   - **PC Device:** Create device auth credentials in Firebase Auth

### PC Detector Setup

1. Navigate to the detector directory:
   ```bash
   cd Driver-Drowsiness-AI
   ```

2. Create virtual environment:
   ```bash
   python -m venv .venv
   .venv\Scripts\activate  # Windows
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create `.env` file with Firebase credentials:
   ```env
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_SYSTEM_ID=your-system-id
   FIREBASE_DEVICE_EMAIL=device@example.com
   FIREBASE_DEVICE_PASSWORD=device-password
   ```

5. Run the detector:
   ```bash
   python main.py
   ```

### Mobile App Setup

1. Navigate to project root:
   ```bash
   cd vigidrive
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Ensure `google-services.json` is in `android/app/`

4. Run the app:
   ```bash
   flutter run
   ```

5. Build APK:
   ```bash
   flutter build apk --release
   ```

---

## Firestore Data Structure

### Systems Collection
```
systems/{systemId}
├── ownerUid: string              # Mobile app user ID
├── deviceAuthUid: string         # PC device auth ID
├── name: string                  # System display name
├── driverName: string            # Driver name
├── driverPhone: string?          # Optional phone number
├── isConnected: boolean          # Real-time connection status
├── isOnline: boolean             # Online status
├── connectionStatus: string      # "online" | "offline"
├── lastHeartbeat: timestamp?     # Last heartbeat time
└── hasUnresolvedViolations: boolean
```

### Violations Subcollection
```
systems/{systemId}/violations/{violationId}
├── systemId: string              # Parent system ID
├── timestamp: timestamp          # Detection time
├── type: string                  # "drowsiness"
├── durationSeconds: number       # Episode duration
├── confidence: number?           # ML confidence (null for EAR)
├── driverName: string            # Driver name
├── recordingPath: string?        # Local PC path to MP4
└── resolved: boolean             # Resolution status
```

---

## Important Limitations

### Current Implementation

✅ **Implemented:**
- Real-time drowsiness detection
- Local MP4 recording on PC
- Firebase/Firestore integration
- Mobile app with real-time sync
- Secure authentication and rules
- Heartbeat online/offline tracking

⚠️ **Current Limitations:**
- **Recordings are stored LOCALLY on the monitoring PC**
  - Not uploaded to Firebase Storage
  - Not available for remote playback in mobile app
  - `recordingPath` field contains local PC file path only
  
- **Firebase Storage / Blaze plan is NOT required**
  - System works entirely on Spark (free) plan
  - No cloud storage costs

- **Single system support**
  - Mobile app currently shows violations from first system only
  - Easy to extend to multi-system in future

### Why Recordings Are Local

The current implementation stores recordings locally on the PC monitoring system for these reasons:
1. **No Firebase Storage costs** - Keeps project on free tier
2. **No Blaze plan required** - Spark plan is sufficient
3. **Bandwidth efficiency** - No continuous video uploads
4. **Privacy** - Recordings stay on local monitoring system

**Future enhancement:** Add optional Firebase Storage upload for remote playback.

---

## Testing

### Flutter Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

### Python Tests
```bash
cd Driver-Drowsiness-AI
pytest
```

---

## Security

### Firestore Rules
- ✅ PC devices can only create violations in their assigned system
- ✅ PC devices can only update heartbeat fields
- ✅ Mobile users can only read/update systems they own
- ✅ Mobile users can only read violations from their systems
- ✅ All fields validated (type, structure, allowed values)
- ✅ No unauthorized access possible

### Authentication
- ✅ Firebase Auth for mobile users (Email/Password)
- ✅ Firebase Auth for PC devices (device credentials)
- ✅ Secure token-based REST API communication
- ✅ No hardcoded secrets in code

---

## Development

### Key Technologies

**PC Detector:**
- MediaPipe Face Mesh (468 landmarks)
- Eye Aspect Ratio (EAR) algorithm
- OpenCV for video capture and recording
- Firebase REST API for violations
- Heartbeat system (30-second interval)

**Mobile App:**
- Flutter BLoC pattern for state management
- StreamBuilder for real-time Firestore updates
- Repository pattern for data access
- Clean architecture (features-based structure)
- Material Design 3 theme

---

## Project Status

### ✅ Production Ready
- All core features implemented and tested
- End-to-end drowsiness detection working
- Real-time sync between PC and mobile verified
- Security rules deployed and tested
- Professional UI completed
- Documentation complete

### Future Enhancements (Optional)
- Firebase Storage integration for remote playback
- Multi-system support in mobile app
- Advanced analytics dashboard
- Driver behavior reports
- SMS/email alerts
- ML classifier confidence (currently using geometric EAR only)

---

## License

[Specify your license here]

---

## Author

Lakshay

---

## Acknowledgments

- MediaPipe team for face mesh technology
- Flutter team for the excellent framework
- Firebase team for the backend infrastructure

---

**Note:** This is a complete, working system. The recordings being stored locally is an intentional design decision, not a limitation. The system is fully functional without Firebase Storage or a Blaze plan.
