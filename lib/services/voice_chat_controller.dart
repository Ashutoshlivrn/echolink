import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/session_model.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class VoiceChatController extends ChangeNotifier {
  final SignalingService signaling = SignalingService();
  late WebRtcService webrtc;

  static const String defaultServerUrl = 'wss://audio-sharing-server.onrender.com';

  String? _sessionId;
  String? get sessionId => _sessionId;

  bool _isHosting = false;
  bool get isHosting => _isHosting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isMicMuted = false;
  bool get isMicMuted => _isMicMuted;

  bool _isRemoteSpeaking = false;
  bool get isRemoteSpeaking => _isRemoteSpeaking;

  final List<Participant> _participants = [];
  List<Participant> get participants => List.unmodifiable(_participants);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final String _myId = const Uuid().v4().substring(0, 8);

  VoiceChatController() {
    _initWebRtc();
    _listenToSignaling();
  }

  void _initWebRtc() {
    webrtc = WebRtcService(
      onIceCandidateGenerated: (candidate) {
        if (_sessionId != null) {
          signaling.sendIceCandidate(_sessionId!, _isHosting ? 'peer' : 'sender', candidate.toMap());
        }
      },
      onRemoteAudioTrackReceived: (track) {
        debugPrint('[VoiceChat] Remote voice track received!');
        _isRemoteSpeaking = true;
        _isConnected = true;
        notifyListeners();
      },
      onConnectionStateChanged: (state) {
        debugPrint('[VoiceChat] Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isConnected = true;
          notifyListeners();
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                   state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _isConnected = false;
          notifyListeners();
        }
      },
    );
  }

  void _listenToSignaling() {
    signaling.onSessionCreated.listen((data) {
      _sessionId = data['sessionId'] as String?;
      _errorMessage = null;
      notifyListeners();
    });

    signaling.onConnectionRequest.listen((data) async {
      final receiverMap = data['receiver'] as Map<String, dynamic>?;
      if (receiverMap != null && _sessionId != null) {
        final participant = Participant.fromMap(receiverMap);
        participant.status = ParticipantStatus.accepted;
        if (!_participants.any((p) => p.id == participant.id)) {
          _participants.add(participant);
        }
        notifyListeners();

        signaling.acceptReceiver(_sessionId!, participant.id);

        await webrtc.initPeerConnection();
        await webrtc.enableMicrophone();
        final offer = await webrtc.createOffer();
        signaling.sendWebRtcOffer(_sessionId!, participant.id, offer.toMap());

        _isConnected = true;
        notifyListeners();
      }
    });

    signaling.onConnectionAccepted.listen((data) async {
      _isConnected = true;
      _errorMessage = null;
      final senderName = data['senderDevice'] as String? ?? 'Host';
      if (!_participants.any((p) => p.name == senderName)) {
        _participants.add(Participant(id: 'host', name: senderName, status: ParticipantStatus.accepted));
      }
      notifyListeners();
    });

    signaling.onReceiverAccepted.listen((receiverId) async {
      _isConnected = true;
      notifyListeners();
    });

    signaling.onReceiverDisconnected.listen((receiverId) {
      _participants.removeWhere((p) => p.id == receiverId);
      if (_participants.isEmpty) {
        _isConnected = false;
        _isRemoteSpeaking = false;
      }
      notifyListeners();
    });

    signaling.onSessionClosed.listen((message) {
      _isConnected = false;
      _isRemoteSpeaking = false;
      _participants.clear();
      _errorMessage = message;
      notifyListeners();
    });

    signaling.onWebRtcOffer.listen((data) async {
      final offerMap = data['sdp'] as Map<String, dynamic>;
      await webrtc.initPeerConnection();
      await webrtc.enableMicrophone();
      final answer = await webrtc.handleOfferAndCreateAnswer(offerMap);
      if (_sessionId != null) {
        signaling.sendWebRtcAnswer(_sessionId!, _myId, answer.toMap());
      }
      _isConnected = true;
      notifyListeners();
    });

    signaling.onWebRtcAnswer.listen((data) async {
      final answerMap = data['sdp'] as Map<String, dynamic>;
      await webrtc.handleAnswer(answerMap);
      _isConnected = true;
      notifyListeners();
    });

    signaling.onIceCandidate.listen((data) async {
      final candidateMap = data['candidate'] as Map<String, dynamic>?;
      if (candidateMap != null) {
        await webrtc.addIceCandidate(candidateMap);
      }
    });

    signaling.onError.listen((error) {
      _errorMessage = error;
      notifyListeners();
    });
  }

  Future<bool> _requestMicPermission(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for Voice Chat')),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> startVoiceRoom(BuildContext context) async {
    if (!await _requestMicPermission(context)) return;

    _isHosting = true;
    _errorMessage = null;
    notifyListeners();

    final connected = await signaling.connect(defaultServerUrl);
    if (!connected) {
      _errorMessage = 'Could not connect to signaling server.';
      notifyListeners();
      return;
    }

    signaling.createSession(
      deviceName: 'Voice Host',
      senderId: _myId,
    );

    await webrtc.initPeerConnection();
    await webrtc.enableMicrophone();
  }

  Future<void> joinVoiceRoom(BuildContext context, String code) async {
    if (!await _requestMicPermission(context)) return;

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      _errorMessage = 'Please enter a valid Room ID';
      notifyListeners();
      return;
    }

    _isHosting = false;
    _sessionId = cleanCode;
    _errorMessage = null;
    notifyListeners();

    final connected = await signaling.connect(defaultServerUrl);
    if (!connected) {
      _errorMessage = 'Could not connect to signaling server.';
      notifyListeners();
      return;
    }

    signaling.joinSession(
      cleanCode,
      deviceName: 'Voice Participant',
      receiverId: _myId,
    );

    await webrtc.initPeerConnection();
    await webrtc.enableMicrophone();
  }

  void toggleMute() {
    _isMicMuted = !_isMicMuted;
    webrtc.setMicrophoneMuted(_isMicMuted);
    notifyListeners();
  }

  Future<void> leaveRoom() async {
    if (_sessionId != null) {
      signaling.leaveSession(_sessionId!);
    }
    signaling.disconnect();
    await webrtc.dispose();
    _sessionId = null;
    _isHosting = false;
    _isConnected = false;
    _isMicMuted = false;
    _isRemoteSpeaking = false;
    _participants.clear();
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}
