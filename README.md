# Shared Audio: Real-Time Audio Sharing Between Two Android Phones

A complete Flutter and native Kotlin Android application that enables two people to listen to the same audio in real time through separate Bluetooth earphones using **Android AudioPlaybackCapture API**, **WebRTC Low-Latency DataChannels**, an **Android Background Playback Foreground Service**, and a dedicated **Node.js Cloud Signaling Server**.

---

## 🌟 Overview & Architecture

### What the Application Does
1. **Host Phone (Sender)**:
   - Plays media (music, videos, web streams, podcasts, games).
   - The host continues listening normally through their own Bluetooth earphones.
   - Native Android `AudioPlaybackCaptureConfiguration` captures the system playback audio in 48 kHz 16-bit stereo PCM.
   - Captured PCM is streamed via low-latency WebRTC DataChannels (or WebSocket relay fallback) to the connected friend.
2. **Friend Phone (Receiver)**:
   - Connects to the host using a 6-letter Session ID or by scanning a QR Code.
   - Receives raw PCM audio frames over WebRTC.
   - Backed by an Android **Foreground Service (`AudioPlaybackService`)**, allowing uninterrupted background audio playback even when switching to apps like WhatsApp, chatting, or locking the phone screen.
   - Native Android `AudioTrack` plays the incoming PCM directly to the friend's connected Bluetooth earphones (A2DP) with hardware low-latency performance.

```
[Host Phone]
  Instagram/YouTube/Audio Player (Plays audio to Host's Bluetooth Earphones)
           │ (System Audio Mixer)
           ▼
  AudioPlaybackCapture API + MediaProjection + Foreground Service (AudioCaptureService)
           │
           ▼
  Native Kotlin AudioRecord (48kHz, 16-bit Stereo PCM)
           │
           ▼
  Flutter NativeAudioService (EventChannel)
           │
           ▼
  WebRTC PeerConnection (Low-Latency Unordered DataChannel)
           │
           ├───────────────────────────────┐
           │ (P2P Direct UDP via STUN/TURN)│ (WebSocket Relay Fallback)
           ▼                               ▼
  [Friend Phone]                    [Dedicated Cloud Signaling Server]
  Foreground Service (AudioPlaybackService)  (wss://audio-sharing-server.onrender.com)
           │                               │
           ▼                               ▼
  Flutter NativeAudioService ──────────────┘
           │
           ▼
  Native Android AudioTrack (STREAM_MUSIC / LOW_LATENCY)
           │
           ▼
  Friend's Connected Bluetooth Earphones (A2DP)
```

---

## 🔥 Key Recent Upgrades & Features

1. **Zero-Configuration Dedicated Cloud Server**:
   - Built-in connection to `wss://audio-sharing-server.onrender.com`.
   - Users no longer need to manually type or configure any WebSocket IP address in the app. Both Host and Friend devices connect automatically out of the box anywhere over 4G, 5G, or Wi-Fi!

2. **Uninterrupted Background Playback (`AudioPlaybackService.kt`)**:
   - Backed by an Android **Media Playback Foreground Service** with CPU `PARTIAL_WAKE_LOCK`.
   - When the receiver phone switches to WhatsApp, Instagram, or turns off the screen, Android OS maintains the CPU, WebSocket, WebRTC pipeline, and audio track without disconnecting or stopping playback.

3. **Streamlined UI & Instant QR Code Connection**:
   - Simplified user flow with no manual server settings prompts.
   - Host generates a QR code encoded with `audio_sharing://join?session=XXXXXX` for instant 1-tap connection.

---

## 🔬 Critical Feasibility Analysis: Instagram Reels Audio Capture

### Android Audio Capture Policy Explained
Android 10 (API 29) introduced `AudioPlaybackCaptureConfiguration`. Under Android's official security and media architecture:
1. **Default Rule (`ALLOW_CAPTURE_BY_ALL`)**: Apps targeting Android 10+ permit audio playback capture by third-party apps by default.
2. **Opt-Out Rule (`ALLOW_CAPTURE_BY_NONE` or `ALLOW_CAPTURE_BY_SYSTEM`)**: An application can explicitly block third-party capture by:
   - Adding `android:allowAudioPlaybackCapture="false"` to its `AndroidManifest.xml`.
   - Calling `.setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_NONE)` on its `AudioAttributes` in code.
3. **DRM Protection**: Any media protected by Widevine DRM or encrypted streams automatically disables third-party capture at the Android HAL/AudioFlinger level.

### Does Instagram Permit Audio Playback Capture?
- **Finding**: Meta's Instagram app (on modern Android versions) utilizes ExoPlayer configured with `AudioAttributes.ALLOW_CAPTURE_BY_NONE` for Reels, Stories, and copyrighted music tracks to comply with copyright licensing agreements.
- **Observed Behavior**:
  - The transmitting phone **continues playing the Reel audio normally** in the host's earphones.
  - The Android system AudioFlinger **silently excludes the protected audio track** from the `AudioPlaybackCapture` stream.
  - As a result, the captured PCM buffer contains zeroes (silence) while Instagram Reels play.
- **Built-in Diagnostic Detection**:
  Our application includes an integrated **Silence & Policy Detector** in `AudioCaptureService.kt` and a dedicated **Feasibility Test Suite** (`FeasibilityScreen` in the app). If silence is detected while capture is active, the app immediately alerts the user:
  > *"⚠️ Captured audio is silent. The currently playing application (Instagram Reels with copyright protection) is enforcing Android capture restriction (ALLOW_CAPTURE_BY_NONE)."*

### Supported & Tested Applications

| Application / Source | Audio Capture Status | Notes |
|---|---|---|
| **Chrome / Firefox (Web Video/Audio)** | ✅ **Supported** | Plays full web audio/video |
| **YouTube Web (m.youtube.com)** | ✅ **Supported** | Captures web-based playback |
| **VLC & Local Media Players** | ✅ **Supported** | Plays local MP3/MP4/MKV audio |
| **Mobile Games (Unity / Unreal)** | ✅ **Supported** | Full game audio streaming |
| **Open Podcast Apps (AntennaPod, etc.)** | ✅ **Supported** | Unrestricted capture policy |
| **SoundCloud / Bandcamp Web** | ✅ **Supported** | Direct web streaming |
| **Instagram Reels & Stories** | ⚠️ **Restricted by Meta** | Excludes 3rd-party capture via `ALLOW_CAPTURE_BY_NONE` |
| **Netflix / Disney+ / Prime Video** | ❌ **Restricted by DRM** | Widevine L1/L3 DRM prohibits capture |

---

## 🛠️ Project Structure

```
audio_sharing/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # minSdk 29, targetSdk 35
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Permissions, MediaProjection & Playback Foreground Services
│   │       └── kotlin/com/example/audio_sharing/
│   │           ├── MainActivity.kt          # MethodChannel & MediaProjection result handler
│   │           ├── AudioCaptureService.kt   # Foreground Service for Host system audio capture
│   │           ├── AudioPlaybackService.kt  # Foreground Service for Receiver background playback
│   │           ├── AudioPlayerService.kt    # Low-latency AudioTrack PCM player
│   │           ├── BluetoothAudioHelper.kt  # Bluetooth A2DP & audio device monitoring
│   │           └── AudioCaptureManager.kt   # Coordinator & EventChannel bridge
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # Material 3 App & Provider setup
│   ├── models/
│   │   ├── audio_device_info.dart   # Connected Bluetooth/speaker device model
│   │   ├── audio_diagnostics.dart   # RMS dB, peak, and silence telemetry
│   │   └── session_model.dart       # Session, Participant, and Connection stats
│   ├── services/
│   │   ├── native_audio_service.dart# Dart wrapper for Kotlin capture/playback
│   │   ├── signaling_service.dart   # WebSocket client for session & SDP exchange
│   │   ├── webrtc_service.dart      # WebRTC PeerConnection & low-latency DataChannel
│   │   └── session_controller.dart  # Master ChangeNotifier coordinator with auto-sanitization
│   ├── widgets/
│   │   ├── audio_meter.dart         # Live 24-bar audio waveform & VU meter
│   │   ├── custom_button.dart       # Accessible Material 3 action buttons
│   │   └── status_badge.dart        # Status indicators
│   └── features/
│       ├── home/home_screen.dart    # Home dashboard, Bluetooth card & mode selection
│       ├── sender/sender_screen.dart# Host controls, QR code, listeners & audio meter
│       ├── receiver/receiver_screen.dart # Friend controls, QR scanner & volume slider
│       └── feasibility/feasibility_screen.dart # 10s compatibility diagnostic tool
├── server/
│   ├── package.json
│   ├── README.md                    # Server deployment guide (Render, Railway, VPS)
│   └── src/
│       ├── server.js                # HTTP health check & WebSocket server (port 8080)
│       └── signaling.js             # Session ID generation & WebRTC coordination
├── pubspec.yaml                     # Dependencies (flutter_webrtc, mobile_scanner, etc.)
└── README.md
```

---

## 🚀 Setup & Execution Guide

### Prerequisites
- Flutter SDK (>= 3.24.0, Dart >= 3.5.0)
- Android SDK (API 29+ / Android 10+ required for AudioPlaybackCapture)
- Two physical Android phones (Android 10 or higher) with separate Bluetooth earphones

---

### Step 1: Install the App on Both Android Devices

1. Build and run directly via Flutter:
   ```bash
   flutter run
   ```
2. Or build the release/debug APK:
   ```bash
   flutter build apk --debug
   ```
   Install the generated `app-debug.apk` file on both phones.

---

### Step 2: Pair Bluetooth Earphones

- Connect Host's Bluetooth earphones to **Phone 1**.
- Connect Friend's Bluetooth earphones to **Phone 2**.
- The **Bluetooth Output Status Card** on the Home screen automatically detects and shows your earphones (e.g. *"Sony WH-1000XM4 (Bluetooth Connected)"*).

---

### Step 3: Start Audio Sharing

1. **On Phone 1 (Host)**:
   - Tap **Start Sharing**.
   - Android will prompt: *"Start recording or casting with Shared Audio?"*
   - Tap **Start now** (or Allow).
   - Phone 1 displays a unique 6-character Session ID (e.g. `A9F-2K4`) or tap the QR Code icon to display the QR code.
2. **On Phone 2 (Friend)**:
   - Tap **Join Session**.
   - Either enter the 6-character Session ID or tap **Scan QR Code** and scan Phone 1's screen.
   - Tap **Join Session**.
3. **On Phone 1 (Host)**:
   - A dialog banner appears: *"Friend Device wants to join and listen to your audio"*.
   - Tap **Accept & Stream**.
4. **Playback & Background Multitasking**:
   - WebRTC P2P DataChannel establishes immediately.
   - Host plays audio in Chrome, YouTube, VLC, podcasts, or games.
   - Host hears audio in their earphones; Friend receives and plays the exact same audio live in their earphones.
   - The Friend can freely switch to WhatsApp, chat, or lock their screen—the background `AudioPlaybackService` ensures playback continues uninterrupted!

---

## 🔒 Permissions & Privacy

- **RECORD_AUDIO**: Required by Android to initialize `AudioRecord`. Capture is strictly restricted to system playback output via `AudioPlaybackCaptureConfiguration`.
- **FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PROJECTION & FOREGROUND_SERVICE_MEDIA_PLAYBACK**: Required by Android 10-15 to keep both capture (Host) and playback (Receiver) services alive in the background while users switch to other apps like WhatsApp.
- **BLUETOOTH_CONNECT**: Required by Android 12+ to detect connected Bluetooth headsets and query friendly names.
- **CAMERA**: Used solely for scanning the session QR code on the receiver device.
- **No Data Retention**: Audio is streamed in memory directly between devices over WebRTC and is **never stored, uploaded, or saved**.
