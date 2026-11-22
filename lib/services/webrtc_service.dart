import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/session_model.dart';

class WebRtcService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  final void Function(Uint8List data)? onAudioChunkReceived;
  final void Function(MediaStreamTrack track)? onRemoteAudioTrackReceived;
  final void Function(RTCIceCandidate candidate)? onIceCandidateGenerated;
  final void Function(RTCPeerConnectionState state)? onConnectionStateChanged;
  final void Function(ConnectionStats stats)? onStatsUpdated;

  int _bytesSent = 0;
  int _bytesReceived = 0;
  final int _lastLatencyMs = 25;
  Timer? _statsTimer;

  MediaStream? _localStream;
  MediaStreamTrack? _localMicTrack;

  // Standard public STUN servers for NAT traversal + optional TURN
  static const Map<String, dynamic> defaultIceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  WebRtcService({
    this.onAudioChunkReceived,
    this.onRemoteAudioTrackReceived,
    this.onIceCandidateGenerated,
    this.onConnectionStateChanged,
    this.onStatsUpdated,
  });

  /// Initialize Peer Connection with ICE configuration.
  Future<void> initPeerConnection({Map<String, dynamic>? customIceConfig}) async {
    await dispose();

    final config = customIceConfig ?? defaultIceServers;
    final Map<String, dynamic> constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(config, constraints);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        onIceCandidateGenerated?.call(candidate);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      onConnectionStateChanged?.call(state);
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.track.kind == 'audio') {
        try {
          await Helper.setSpeakerphoneOn(true);
        } catch (_) {}
        onRemoteAudioTrackReceived?.call(event.track);
      }
    };

    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      debugPrint('[WebRTC] Received remote DataChannel: ${channel.label}');
      _setupDataChannel(channel);
    };

    _startStatsMonitoring();
  }

  /// Enable microphone capture and add audio track to PeerConnection, returning renegotiation offer if needed
  Future<RTCSessionDescription?> enableMicrophone() async {
    try {
      if (_localMicTrack != null) {
        _localMicTrack!.enabled = true;
        return null;
      }

      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      final tracks = _localStream!.getAudioTracks();
      if (tracks.isNotEmpty) {
        _localMicTrack = tracks.first;
        _localMicTrack!.enabled = true;

        if (_peerConnection != null) {
          await _peerConnection!.addTrack(_localMicTrack!, _localStream!);
          debugPrint('[WebRTC] Local microphone track added to PeerConnection');
          final offer = await createOffer();
          return offer;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WebRTC] Error enabling microphone: $e');
      return null;
    }
  }

  /// Mute or unmute local microphone track
  void setMicrophoneMuted(bool isMuted) {
    if (_localMicTrack != null) {
      _localMicTrack!.enabled = !isMuted;
      debugPrint('[WebRTC] Microphone muted: $isMuted');
    }
  }

  /// Sender setup: creates a dedicated low-latency audio DataChannel.
  Future<RTCDataChannel> createAudioDataChannel() async {
    if (_peerConnection == null) {
      throw StateError('PeerConnection is not initialized');
    }

    final init = RTCDataChannelInit()
      ..ordered = false // Unordered for lowest audio transmission latency
      ..maxRetransmits = 0 // Drop lost frames instead of delaying audio stream
      ..binaryType = 'binary';

    _dataChannel = await _peerConnection!.createDataChannel('audio-stream', init);
    _setupDataChannel(_dataChannel!);
    return _dataChannel!;
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('[WebRTC DataChannel] State: $state');
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        _bytesReceived += message.binary.length;
        onAudioChunkReceived?.call(message.binary);
      }
    };
  }

  /// Sender: Create WebRTC Offer
  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) throw StateError('PeerConnection null');

    final Map<String, dynamic> offerConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
      'optional': [],
    };

    final description = await _peerConnection!.createOffer(offerConstraints);
    await _peerConnection!.setLocalDescription(description);
    return description;
  }

  /// Receiver: Handle Offer and Create WebRTC Answer (reuses existing PC if available)
  Future<RTCSessionDescription> handleOfferAndCreateAnswer(
    Map<String, dynamic> offerMap,
  ) async {
    if (_peerConnection == null) {
      await initPeerConnection();
    }

    final offer = RTCSessionDescription(
      offerMap['sdp'] as String,
      offerMap['type'] as String,
    );
    await _peerConnection!.setRemoteDescription(offer);

    final Map<String, dynamic> answerConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
      'optional': [],
    };

    final answer = await _peerConnection!.createAnswer(answerConstraints);
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  /// Sender: Handle Answer from Receiver
  Future<void> handleAnswer(Map<String, dynamic> answerMap) async {
    if (_peerConnection == null) return;

    final answer = RTCSessionDescription(
      answerMap['sdp'] as String,
      answerMap['type'] as String,
    );
    await _peerConnection!.setRemoteDescription(answer);
  }

  /// Add ICE Candidate received from Signaling
  Future<void> addIceCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;

    final candidate = RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] as int?,
    );
    await _peerConnection!.addCandidate(candidate);
  }

  /// Send raw audio chunk across the DataChannel to receiver
  bool sendAudioChunk(Uint8List chunk) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
        _bytesSent += chunk.length;
        return true;
      } catch (e) {
        debugPrint('[WebRTC] Error sending audio chunk: $e');
        return false;
      }
    }
    return false;
  }

  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_peerConnection != null) {
        try {
          final stats = ConnectionStats(
            latencyMs: _lastLatencyMs,
            packetLoss: 0.0,
            transport: (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen)
                ? 'WebRTC DataChannel (P2P)'
                : 'Connecting...',
            bytesReceived: _bytesReceived,
            bytesSent: _bytesSent,
          );
          onStatsUpdated?.call(stats);
        } catch (_) {}
      }
    });
  }

  Future<void> dispose() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    try {
      _localMicTrack?.stop();
      await _localStream?.dispose();
      await _dataChannel?.close();
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] Dispose error: $e');
    }
    _localMicTrack = null;
    _localStream = null;
    _dataChannel = null;
    _peerConnection = null;
    _bytesSent = 0;
    _bytesReceived = 0;
  }
}
