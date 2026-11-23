import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_device_info.dart';
import '../models/audio_diagnostics.dart';
import '../models/audio_message_model.dart';
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

  bool _isMicEnabled = false;
  bool get isMicEnabled => _isMicEnabled;

  // Audio Messaging Properties
  final List<AudioMessage> _audioMessages = [];
  List<AudioMessage> get audioMessages => List.unmodifiable(_audioMessages);

  bool _isRecordingMessage = false;
  bool get isRecordingMessage => _isRecordingMessage;

  int _recordingDurationSec = 0;
  int get recordingDurationSec => _recordingDurationSec;

  Timer? _recordingTimer;
  final List<Uint8List> _recordedChunks = [];
  StreamSubscription? _msgMicSub;
  StreamSubscription? _audioMsgSub;

  bool _isPlayingAudioMessage = false;
  final List<AudioMessage> _playbackQueue = [];

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
      // Receives offer (Initial or Renegotiation)
      final offerMap = data['sdp'] as Map<String, dynamic>;

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

    signaling.onMicStateChanged.listen((data) {
      final participantId = data['participantId'] as String?;
      final isEnabled = data['isMicEnabled'] as bool? ?? false;
      if (participantId != null) {
        for (var p in _participants) {
          if (p.id == participantId) {
            p.isMicEnabled = isEnabled;
          }
        }
        notifyListeners();
      }
    });

    _audioMsgSub = signaling.onAudioMessage.listen((data) {
      final msg = AudioMessage.fromMap(data);
      _audioMessages.add(msg);
      _playbackQueue.add(msg);
      notifyListeners();
      _processPlaybackQueue();
    });
  }

  Future<void> startRecordingAudioMessage(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return;
    }

    _isRecordingMessage = true;
    _recordingDurationSec = 0;
    _recordedChunks.clear();
    notifyListeners();

    _msgMicSub = nativeAudio.micStream.listen((chunk) {
      if (_isRecordingMessage) {
        _recordedChunks.add(chunk);
      }
    });

    await nativeAudio.startMicCapture();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDurationSec++;
      notifyListeners();
    });
  }

  void cancelAudioMessage() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _msgMicSub?.cancel();
    _msgMicSub = null;
    nativeAudio.stopMicCapture();
    _isRecordingMessage = false;
    _recordingDurationSec = 0;
    _recordedChunks.clear();
    notifyListeners();
  }

  Future<void> stopAndSendAudioMessage() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _msgMicSub?.cancel();
    _msgMicSub = null;
    await nativeAudio.stopMicCapture();

    _isRecordingMessage = false;
    notifyListeners();

    if (_recordedChunks.isEmpty) return;

    int totalLen = _recordedChunks.fold(0, (sum, c) => sum + c.length);
    Uint8List combined = Uint8List(totalLen);
    int offset = 0;
    for (var chunk in _recordedChunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    final durationMs = (_recordingDurationSec > 0 ? _recordingDurationSec : 1) * 1000;
    final senderName = _role == SessionRole.sender ? 'Host' : 'Friend';

    final msg = AudioMessage(
      id: const Uuid().v4(),
      senderId: _myDeviceId,
      senderName: senderName,
      audioData: combined,
      durationMs: durationMs,
      timestamp: DateTime.now(),
    );

    _audioMessages.add(msg);
    _recordingDurationSec = 0;
    _recordedChunks.clear();
    notifyListeners();

    if (_sessionId != null) {
      signaling.sendAudioMessage(_sessionId!, msg);
    }
  }

  Future<void> _processPlaybackQueue() async {
    if (_isPlayingAudioMessage || _playbackQueue.isEmpty) return;
    _isPlayingAudioMessage = true;

    final msg = _playbackQueue.removeAt(0);
    msg.isPlaying = true;
    notifyListeners();

    try {
      await nativeAudio.startAudioPlayer(sampleRate: 16000, channels: 1);
      await nativeAudio.setPlayerVolume(1.0);

      int chunkSize = 4096;
      for (int i = 0; i < msg.audioData.length; i += chunkSize) {
        int end = (i + chunkSize < msg.audioData.length) ? i + chunkSize : msg.audioData.length;
        Uint8List slice = msg.audioData.sublist(i, end);
        await nativeAudio.writeAudioChunk(slice);
        await Future.delayed(const Duration(milliseconds: 15));
      }

      await Future.delayed(const Duration(milliseconds: 300));
      await nativeAudio.stopAudioPlayer();
    } catch (e) {
      debugPrint('[SessionController] Error playing audio message: $e');
    }

    msg.isPlaying = false;
    _isPlayingAudioMessage = false;
    notifyListeners();

    _processPlaybackQueue();
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

  Future<void> toggleMic(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Microphone Permission Required'),
              content: const Text(
                'Live Talk requires microphone access so you can speak with participants in real time. Please grant microphone access in Android Settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    _isMicEnabled = !_isMicEnabled;
    if (_isMicEnabled) {
      final offer = await webrtc.enableMicrophone();
      if (offer != null && _sessionId != null) {
        if (_role == SessionRole.sender) {
          for (var p in _participants) {
            if (p.status == ParticipantStatus.accepted) {
              signaling.sendWebRtcOffer(_sessionId!, p.id, offer.toMap());
            }
          }
        } else {
          signaling.sendWebRtcOffer(_sessionId!, _myDeviceId, offer.toMap());
        }
      }
    } else {
      webrtc.setMicrophoneMuted(true);
    }

    if (_sessionId != null) {
      signaling.sendMicState(_sessionId!, _myDeviceId, _isMicEnabled);
    }
    notifyListeners();
  }

  /// Host / Sender Flow: Start sharing session
  Future<void> startSharing({String? customId}) async {
    _ensureValidServerUrl();
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
    _isMicEnabled = false;
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
    _msgMicSub?.cancel();
    _audioMsgSub?.cancel();
    _recordingTimer?.cancel();
    webrtc.dispose();
    nativeAudio.dispose();
    signaling.dispose();
    super.dispose();
  }
}
