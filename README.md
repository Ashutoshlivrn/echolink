# Shared Audio: Real-Time P2P Audio Sharing App for Android

**Shared Audio** is a production-ready, ultra-low latency Android application built with **Flutter (Dart)** and **Native Kotlin**, enabling two people to listen to the exact same audio simultaneously in real time through separate Bluetooth earphones. 

It leverages the **Android AudioPlaybackCapture API**, **WebRTC Low-Latency P2P DataChannels**, **Foreground Media Playback Services**, and a dedicated **Cloud Signaling WebSocket Server**.

---

## 🌟 Key Production Features & Architecture

### 1. Ultra-Low Latency WebRTC P2P DataChannels
- Audio captured on the host device is transmitted directly to connected friends using unordered, unreliable WebRTC DataChannels (`maxRetransmits = 0`) to guarantee zero audio buffer delay.
- Supports STUN/TURN NAT traversal for connection anywhere across cellular (4G/5G) and Wi-Fi networks.

### 2. Uninterrupted Background Playback (`AudioPlaybackService`)
- Backed by an Android **Media Playback Foreground Service** with CPU `PARTIAL_WAKE_LOCK`.
- When the friend (receiver) switches to WhatsApp, Instagram, or turns off the screen, Android OS maintains the CPU, WebSocket, WebRTC pipeline, and native `AudioTrack` without interrupting playback.

### 3. Robust Connection & Disconnection Handling
- **Instant Cleanup**: If either the host or receiver ends the connection, all streaming stops immediately, audio capture is released, the native `AudioTrack` stops, and both UIs reset gracefully.
- **Auto-Sanitized Server URL**: Connects out of the box to the zero-configuration cloud signaling server (`wss://audio-sharing-server.onrender.com`).

### 4. Bluetooth A2DP & Audio Device Routing
- Automatically detects connected Bluetooth earphones, headsets, or car audio systems and routes playback directly through hardware low-latency pathways (`STREAM_MUSIC`).

---

## 📦 Google Play Store Submission Guide

### Prerequisites & SDK Target
- **minSdk**: API 29 (Android 10) — required for `AudioPlaybackCaptureConfiguration`.
- **targetSdk**: API 35 (Android 15+) — compliant with latest Google Play requirements.
- **Compile SDK**: API 35.

### Required Android Manifest Permissions
Ensure your `AndroidManifest.xml` includes the necessary permissions and foreground service declarations:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Building the Release App Bundle (.aab)
To generate a production-ready App Bundle for Google Play Console upload:
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
The signed AAB file will be located at:
`build/app/outputs/bundle/release/app-release.aab`

---

## 🔬 Audio Capture Policy & Feasibility Notes

### Android Audio Capture Restrictions
Android 10+ introduced audio playback capture security policies. Depending on the source app:
1. **Unrestricted Apps** (YouTube web, Chrome, VLC, local media players, mobile games, podcasts): Fully captured and streamed in 48kHz stereo PCM.
2. **Restricted Apps** (Instagram Reels / Stories): Meta enforces `ALLOW_CAPTURE_BY_NONE` to protect copyrighted music. The app includes an integrated **Silence & Policy Detector** that instantly alerts users if captured audio is silent due to third-party restrictions.
3. **DRM Protected Content** (Netflix, Disney+, Prime Video): Protected by Widevine DRM at the HAL level and automatically excluded from capture.

---

## 🛠️ Project Structure

```
audio_sharing/
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   └── kotlin/com/example/audio_sharing/
│       ├── MainActivity.kt
│       ├── AudioCaptureService.kt
│       ├── AudioPlaybackService.kt
│       ├── AudioPlayerService.kt
│       └── BluetoothAudioHelper.kt
├── lib/
│   ├── app.dart                   # Material 3 Theme & Route transitions
│   ├── main.dart                  # Entry point & orientation locks
│   ├── features/
│   │   ├── splash/splash_screen.dart # Animated production splash screen
│   │   ├── home/home_screen.dart     # Dashboard & device status
│   │   ├── sender/sender_screen.dart # Host controls & QR code sharing
│   │   ├── receiver/receiver_screen.dart # Friend controls & QR scanner
│   │   └── feasibility/feasibility_screen.dart # Compatibility diagnostic
│   ├── models/
│   └── services/
│       ├── session_controller.dart   # State coordination & auto-cleanup
│       ├── signaling_service.dart    # WebSocket signaling client
│       └── webrtc_service.dart       # P2P WebRTC DataChannel engine
└── server/                           # Node.js Signaling Server
```

---

## 🚀 License & Support
Published under MIT License. Ready for deployment and Google Play Console submission.
