import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_device_info.dart';
import '../models/audio_diagnostics.dart';
import '../models/session_model.dart';
import 'native_audio_service.dart';
import 'signaling_service.dart';
import 'webrtc_service.dart';

class SessionController extends ChangeNotifier {
  final NativeAudioService nativeAudio = NativeAudioService();
  final SignalingService signaling = SignalingService();
  late WebRtcService webrtc;

  // Server URL Configuration
  static const String defaultServerUrl = 'wss://audio-sharing-server.onrender.com';
  String _serverUrl = defaultServerUrl;
  String get serverUrl => _serverUrl;

  SessionRole? _role;
  SessionRole? get role => _role;

  SessionState _state = SessionState.idle;
  SessionState get state => _state;

  String? _sessionId;
  String? get sessionId => _sessionId;

  final String _myDeviceId = const Uuid().v4().substring(0, 8);
  String get myDeviceId => _myDeviceId;

  final List<Participant> _participants = [];
  List<Participant> get participants => List.unmodifiable(_participants);

  Participant? _pendingRequest;
  Participant? get pendingRequest => _pendingRequest;

  AudioDiagnostics _diagnostics = AudioDiagnostics.empty();
  AudioDiagnostics get diagnostics => _diagnostics;

  ConnectionStats _connectionStats = const ConnectionStats();
  ConnectionStats get connectionStats => _connectionStats;

  List<AudioDeviceInfo> _audioDevices = [];
  List<AudioDeviceInfo> get audioDevices => _audioDevices;

  AudioDeviceInfo? _activeAudioDevice;
  AudioDeviceInfo? get activeAudioDevice => _activeAudioDevice;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  double _playerVolume = 1.0;
  double get playerVolume => _playerVolume;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _warningMessage;
  String? get warningMessage => _warningMessage;

  StreamSubscription? _audioSub;
  StreamSubscription? _diagnosticsSub;
  StreamSubscription? _devicesSub;

  SessionController() {
    _ensureValidServerUrl();
    _initWebRtc();
    _listenToNativeStreams();
    _listenToSignalingStreams();
    refreshDevices();
  }

  void _initWebRtc() {
    webrtc = WebRtcService(
      onAudioChunkReceived: _onAudioChunkFromWebRtc,
      onIceCandidateGenerated: (candidate) {
        if (_sessionId != null) {
          signaling.sendIceCandidate(_sessionId!, 'peer', candidate.toMap());
        }
      },
      onConnectionStateChanged: (connState) {
        debugPrint('[Controller] WebRTC state: $connState');
      },
      onStatsUpdated: (stats) {
        _connectionStats = stats;
        notifyListeners();
      },
    );
  }

  void _listenToNativeStreams() {
    // Audio stream from native capture (Sender)
    _audioSub = nativeAudio.audioStream.listen((Uint8List chunk) {
      if (_role == SessionRole.sender && _state == SessionState.streaming) {
        // Send via WebRTC DataChannel
        final sent = webrtc.sendAudioChunk(chunk);
        // Fallback: If WebRTC DataChannel isn't open, relay via Signaling WebSocket
        if (!sent && _sessionId != null) {
          signaling.sendAudioRelay(_sessionId!, chunk);
        }
      }
    });

    // Capture diagnostics (RMS dB, silence detection)
    _diagnosticsSub = nativeAudio.diagnosticsStream.listen((diag) {
      _diagnostics = diag;

      // Detect if user is playing restricted audio (e.g. Instagram ALLOW_CAPTURE_BY_NONE)
      if (_isCapturing && diag.isSilence && diag.totalBytes > 100000) {
        _warningMessage =
            '⚠️ Captured audio is silent. The currently playing application '
            '(such as Instagram Reels with copyright protection) may be enforcing '
            'Android capture restriction (ALLOW_CAPTURE_BY_NONE).';
      } else {
        _warningMessage = null;
      }
      notifyListeners();
    });

    // Device list updates
    _devicesSub = nativeAudio.devicesStream.listen((devices) {
      _audioDevices = devices;
      _updateActiveDevice(devices);
      notifyListeners();
    });
  }

  void _listenToSignalingStreams() {
    signaling.onSessionCreated.listen((data) {
      _sessionId = data['sessionId'] as String?;
      _state = SessionState.ready;
      _errorMessage = null;
      notifyListeners();
    });

    signaling.onConnectionRequest.listen((data) {
      final receiverMap = data['receiver'] as Map<String, dynamic>?;
      if (receiverMap != null) {
        _pendingRequest = Participant.fromMap(receiverMap);
        notifyListeners();
      }
    });

    signaling.onReceiverAccepted.listen((receiverId) async {
      // Sender: Participant accepted, now create WebRTC offer
      final participant = _participants.firstWhere(
        (p) => p.id == receiverId,
        orElse: () => Participant(id: receiverId, name: 'Friend Device'),
      );
      participant.status = ParticipantStatus.accepted;
      if (!_participants.contains(participant)) {
        _participants.add(participant);
      }

      await webrtc.initPeerConnection();
      await webrtc.createAudioDataChannel();
      final offer = await webrtc.createOffer();

      if (_sessionId != null) {
        signaling.sendWebRtcOffer(_sessionId!, receiverId, offer.toMap());
      }
      _state = SessionState.streaming;
      notifyListeners();
    });

    signaling.onConnectionAccepted.listen((data) {
      // Receiver: Connection was accepted by host
      _state = SessionState.streaming;
      _errorMessage = null;
      _startReceiverPlayback();
      notifyListeners();
    });

    signaling.onConnectionRejected.listen((reason) {
      _state = SessionState.error;
      _errorMessage = reason;
      notifyListeners();
    });

    signaling.onReceiverDisconnected.listen((receiverId) {
      _participants.removeWhere((p) => p.id == receiverId);
      notifyListeners();
    });

    signaling.onSessionClosed.listen((message) {
      _state = SessionState.disconnected;
      _errorMessage = message;
      _stopReceiverPlayback();
      notifyListeners();
    });

    signaling.onWebRtcOffer.listen((data) async {
      // Receiver receives offer from Sender
      final offerMap = data['sdp'] as Map<String, dynamic>;

      await webrtc.initPeerConnection();
      final answer = await webrtc.handleOfferAndCreateAnswer(offerMap);

      if (_sessionId != null) {
        signaling.sendWebRtcAnswer(_sessionId!, _myDeviceId, answer.toMap());
      }
    });

    signaling.onWebRtcAnswer.listen((data) async {
      // Sender receives answer from Receiver
      final answerMap = data['sdp'] as Map<String, dynamic>;
      await webrtc.handleAnswer(answerMap);
    });

    signaling.onIceCandidate.listen((data) async {
      final candidateMap = data['candidate'] as Map<String, dynamic>?;
      if (candidateMap != null) {
        await webrtc.addIceCandidate(candidateMap);
      }
    });

    signaling.onAudioRelay.listen((Uint8List chunk) {
      // Receiver fallback audio via WebSocket
      if (_role == SessionRole.receiver && _isPlaying) {
        nativeAudio.writeAudioChunk(chunk);
      }
    });

    signaling.onError.listen((error) {
      _errorMessage = error;
      _state = SessionState.error;
      notifyListeners();
    });
  }

  void _onAudioChunkFromWebRtc(Uint8List chunk) {
    if (_role == SessionRole.receiver && _isPlaying) {
      nativeAudio.writeAudioChunk(chunk);
    }
  }

  void _updateActiveDevice(List<AudioDeviceInfo> devices) {
    // Prefer Bluetooth device if connected
    final btDevice = devices.firstWhere(
      (d) => d.isBluetooth,
      orElse: () => devices.isNotEmpty
          ? devices.first
          : const AudioDeviceInfo(
              id: 0,
              name: 'Phone Speaker',
              type: 'Speaker',
              isBluetooth: false,
              sampleRates: [48000],
            ),
    );
    _activeAudioDevice = btDevice;
  }

  Future<void> refreshDevices() async {
    final list = await nativeAudio.getAudioDevices();
    _audioDevices = list;
    _updateActiveDevice(list);
    notifyListeners();
  }

  void resetServerUrl() {
    _serverUrl = defaultServerUrl;
    notifyListeners();
  }

  void setServerUrl(String url) {
    String cleanUrl = url.trim();
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (cleanUrl.startsWith('https://')) {
      cleanUrl = cleanUrl.replaceFirst('https://', 'wss://');
    } else if (cleanUrl.startsWith('http://')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'ws://');
    }
    // Automatically sanitize legacy local IP inputs to production URL
    if (cleanUrl.contains('192.168.') || cleanUrl.contains('10.0.2.2') || cleanUrl.contains('10F')) {
      cleanUrl = defaultServerUrl;
    }
    _serverUrl = cleanUrl.isEmpty ? defaultServerUrl : cleanUrl;
    notifyListeners();
  }

  void _ensureValidServerUrl() {
    // If the server URL is unconfigured or still holds a legacy local IP, automatically reset to production server URL
    if (_serverUrl.isEmpty ||
        _serverUrl.contains('192.168.') ||
        _serverUrl.contains('10F') ||
        _serverUrl.contains('10.0.2.2')) {
      _serverUrl = defaultServerUrl;
    }
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Host / Sender Flow: Start sharing session
  Future<void> startSharing({String? customId}) async {
    _ensureValidServerUrl();

    // Check microphone / audio capture permission with prompt fallback
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _role = SessionRole.sender;
        _state = SessionState.error;
        _errorMessage = micStatus.isPermanentlyDenied
            ? 'Microphone permission is permanently denied. Please tap below to open App Settings and grant permission.'
            : 'Microphone permission is required to capture and share audio. Please allow permission to continue.';
        notifyListeners();
        return;
      }
    }

    _role = SessionRole.sender;
    _state = SessionState.connecting;
    _sessionId = null;
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();

    final connected = await signaling.connect(_serverUrl);
    if (!connected) {
      _state = SessionState.error;
      _errorMessage = 'Could not connect to signaling server at $_serverUrl. Please check your internet connection.';
      notifyListeners();
      return;
    }

    signaling.createSession(
      customId: customId,
      deviceName: _activeAudioDevice?.name ?? 'Android Sender',
      senderId: _myDeviceId,
    );

    // Request MediaProjection and start native audio capture
    final captureStarted = await nativeAudio.startAudioCapture();
    _isCapturing = captureStarted;
    if (!captureStarted) {
      _warningMessage =
          'Audio capture permission not granted. Please allow screen/audio capture.';
    }
    notifyListeners();
  }

  /// Accept incoming connection request from a friend
  void acceptIncomingRequest() {
    if (_pendingRequest != null && _sessionId != null) {
      final req = _pendingRequest!;
      req.status = ParticipantStatus.accepted;
      _participants.add(req);
      signaling.acceptReceiver(_sessionId!, req.id);
      _pendingRequest = null;
      notifyListeners();
    }
  }

  /// Reject incoming connection request
  void rejectIncomingRequest({String? reason}) {
    if (_pendingRequest != null && _sessionId != null) {
      signaling.rejectReceiver(
        _sessionId!,
        _pendingRequest!.id,
        reason: reason ?? 'Request declined by host',
      );
      _pendingRequest = null;
      notifyListeners();
    }
  }

  /// Friend / Receiver Flow: Join an existing session
  Future<void> joinSession(String code) async {
    _ensureValidServerUrl();
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      _errorMessage = 'Please enter a valid Session ID';
      notifyListeners();
      return;
    }

    _role = SessionRole.receiver;
    _state = SessionState.connecting;
    _sessionId = cleanCode;
    _errorMessage = null;
    notifyListeners();

    final connected = await signaling.connect(_serverUrl);
    if (!connected) {
      _state = SessionState.error;
      _errorMessage = 'Could not connect to signaling server at $_serverUrl';
      notifyListeners();
      return;
    }

    _state = SessionState.waitingApproval;
    signaling.joinSession(
      cleanCode,
      deviceName: _activeAudioDevice?.name ?? 'Android Friend',
      receiverId: _myDeviceId,
    );
    notifyListeners();
  }

  Future<void> _startReceiverPlayback() async {
    final started = await nativeAudio.startAudioPlayer(sampleRate: 48000, channels: 2);
    _isPlaying = started;
    await nativeAudio.setPlayerVolume(_playerVolume);
    notifyListeners();
  }

  Future<void> _stopReceiverPlayback() async {
    await nativeAudio.stopAudioPlayer();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _playerVolume = volume.clamp(0.0, 1.0);
    await nativeAudio.setPlayerVolume(_playerVolume);
    notifyListeners();
  }

  Future<void> toggleAudioCapture() async {
    if (_isCapturing) {
      await nativeAudio.stopAudioCapture();
      _isCapturing = false;
    } else {
      _isCapturing = await nativeAudio.startAudioCapture();
    }
    notifyListeners();
  }

  /// Disconnect and clean up session
  Future<void> disconnectSession() async {
    if (_sessionId != null) {
      signaling.leaveSession(_sessionId!);
    }
    signaling.disconnect();
    await webrtc.dispose();
    await nativeAudio.stopAudioCapture();
    await nativeAudio.stopAudioPlayer();

    _isCapturing = false;
    _isPlaying = false;
    _sessionId = null;
    _role = null;
    _state = SessionState.idle;
    _pendingRequest = null;
    _participants.clear();
    _errorMessage = null;
    _warningMessage = null;
    _diagnostics = AudioDiagnostics.empty();
    _connectionStats = const ConnectionStats();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _diagnosticsSub?.cancel();
    _devicesSub?.cancel();
    webrtc.dispose();
    nativeAudio.dispose();
    signaling.dispose();
    super.dispose();
  }
}
