import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/audio_message_model.dart';

class SignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Timer? _heartbeatTimer;

  bool get isConnected => _isConnected;

  // Stream controllers for signaling events
  final _onSessionCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onConnectionRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _onConnectionAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onConnectionRejectedController = StreamController<String>.broadcast();
  final _onReceiverAcceptedController = StreamController<String>.broadcast();
  final _onReceiverDisconnectedController = StreamController<String>.broadcast();
  final _onSessionClosedController = StreamController<String>.broadcast();
  final _onWebRtcOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _onWebRtcAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  final _onIceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _onAudioRelayController = StreamController<Uint8List>.broadcast();
  final _onMicRelayController = StreamController<Uint8List>.broadcast();
  final _onMicStateChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onAudioMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _onErrorController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onSessionCreated => _onSessionCreatedController.stream;
  Stream<Map<String, dynamic>> get onConnectionRequest => _onConnectionRequestController.stream;
  Stream<Map<String, dynamic>> get onConnectionAccepted => _onConnectionAcceptedController.stream;
  Stream<String> get onConnectionRejected => _onConnectionRejectedController.stream;
  Stream<String> get onReceiverAccepted => _onReceiverAcceptedController.stream;
  Stream<String> get onReceiverDisconnected => _onReceiverDisconnectedController.stream;
  Stream<String> get onSessionClosed => _onSessionClosedController.stream;
  Stream<Map<String, dynamic>> get onWebRtcOffer => _onWebRtcOfferController.stream;
  Stream<Map<String, dynamic>> get onWebRtcAnswer => _onWebRtcAnswerController.stream;
  Stream<Map<String, dynamic>> get onIceCandidate => _onIceCandidateController.stream;
  Stream<Uint8List> get onAudioRelay => _onAudioRelayController.stream;
  Stream<Uint8List> get onMicRelay => _onMicRelayController.stream;
  Stream<Map<String, dynamic>> get onMicStateChanged => _onMicStateChangedController.stream;
  Stream<Map<String, dynamic>> get onAudioMessage => _onAudioMessageController.stream;
  Stream<String> get onError => _onErrorController.stream;

  Future<bool> connect(String serverUrl) async {
    try {
      disconnect();
      debugPrint('[Signaling] Connecting to $serverUrl');
      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (dynamic error) {
          debugPrint('[Signaling] WebSocket error: $error');
          _isConnected = false;
          _onErrorController.add('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('[Signaling] WebSocket connection closed');
          if (_isConnected) {
            _isConnected = false;
            _onSessionClosedController.add('Disconnected from signaling server');
          }
        },
      );

      // Wait until the WebSocket handshake is completed successfully (with 15s timeout)
      await _channel!.ready.timeout(const Duration(seconds: 15));

      _isConnected = true;
      _startHeartbeat();
      return true;
    } catch (e) {
      debugPrint('[Signaling] Connection failed: $e');
      _isConnected = false;
      _onErrorController.add('Could not connect to signaling server at $serverUrl: $e');
      return false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected) {
        send({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
      final String type = data['type'] as String? ?? '';

      switch (type) {
        case 'session-created':
          _onSessionCreatedController.add(data);
          break;

        case 'connection-request':
          _onConnectionRequestController.add(data);
          break;

        case 'connection-accepted':
          _onConnectionAcceptedController.add(data);
          break;

        case 'connection-rejected':
          _onConnectionRejectedController.add(data['message'] as String? ?? 'Connection rejected');
          break;

        case 'receiver-accepted':
          _onReceiverAcceptedController.add(data['receiverId'] as String? ?? '');
          break;

        case 'receiver-disconnected':
          _onReceiverDisconnectedController.add(data['receiverId'] as String? ?? '');
          break;

        case 'session-closed':
          _onSessionClosedController.add(data['message'] as String? ?? 'Session ended');
          break;

        case 'webrtc-offer':
          _onWebRtcOfferController.add(data);
          break;

        case 'webrtc-answer':
          _onWebRtcAnswerController.add(data);
          break;

        case 'ice-candidate':
          _onIceCandidateController.add(data);
          break;

        case 'audio-relay':
          final base64String = data['data'] as String?;
          if (base64String != null) {
            final bytes = base64Decode(base64String);
            _onAudioRelayController.add(bytes);
          }
          break;

        case 'mic-relay':
          final base64String = data['data'] as String?;
          if (base64String != null) {
            final bytes = base64Decode(base64String);
            _onMicRelayController.add(bytes);
          }
          break;

        case 'mic-state-changed':
          _onMicStateChangedController.add(data);
          break;

        case 'audio-message':
          _onAudioMessageController.add(data);
          break;

        case 'error':
        case 'join-failed':
        case 'session-created-failed':
          _onErrorController.add(data['message'] as String? ?? 'Signaling error');
          break;

        case 'pong':
          // Heartbeat ack
          break;

        default:
          debugPrint('[Signaling] Unhandled message type: $type');
      }
    } catch (e) {
      debugPrint('[Signaling] Message parse error: $e');
    }
  }

  void createSession({String? customId, String? deviceName, String? senderId}) {
    send({
      'type': 'create-session',
      'payload': {
        'customId': customId,
        'deviceName': deviceName ?? 'Android Host',
        'senderId': senderId,
      }
    });
  }

  void joinSession(String sessionId, {String? deviceName, String? receiverId}) {
    send({
      'type': 'join-session',
      'sessionId': sessionId,
      'payload': {
        'deviceName': deviceName ?? 'Android Friend',
        'receiverId': receiverId,
      }
    });
  }

  void acceptReceiver(String sessionId, String receiverId) {
    send({
      'type': 'accept-request',
      'sessionId': sessionId,
      'payload': {
        'receiverId': receiverId,
      }
    });
  }

  void rejectReceiver(String sessionId, String receiverId, {String? reason}) {
    send({
      'type': 'reject-request',
      'sessionId': sessionId,
      'payload': {
        'receiverId': receiverId,
        'reason': reason,
      }
    });
  }

  void sendWebRtcOffer(String sessionId, String targetReceiverId, Map<String, dynamic> sdp) {
    send({
      'type': 'webrtc-offer',
      'sessionId': sessionId,
      'payload': {
        'targetReceiverId': targetReceiverId,
        'sdp': sdp,
      }
    });
  }

  void sendWebRtcAnswer(String sessionId, String receiverId, Map<String, dynamic> sdp) {
    send({
      'type': 'webrtc-answer',
      'sessionId': sessionId,
      'payload': {
        'receiverId': receiverId,
        'sdp': sdp,
      }
    });
  }

  void sendIceCandidate(String sessionId, String targetId, Map<String, dynamic> candidate) {
    send({
      'type': 'ice-candidate',
      'sessionId': sessionId,
      'payload': {
        'targetId': targetId,
        'candidate': candidate,
      }
    });
  }

  void sendAudioRelay(String sessionId, Uint8List chunk) {
    send({
      'type': 'audio-relay',
      'sessionId': sessionId,
      'payload': {
        'data': base64Encode(chunk),
      }
    });
  }

  void sendMicState(String sessionId, String participantId, bool isMicEnabled) {
    send({
      'type': 'mic-state-changed',
      'sessionId': sessionId,
      'payload': {
        'participantId': participantId,
        'isMicEnabled': isMicEnabled,
      }
    });
  }

  void sendMicRelay(String sessionId, Uint8List chunk) {
    send({
      'type': 'mic-relay',
      'sessionId': sessionId,
      'payload': {
        'data': base64Encode(chunk),
      }
    });
  }

  void sendAudioMessage(String sessionId, AudioMessage message) {
    send({
      'type': 'audio-message',
      'sessionId': sessionId,
      'payload': message.toMap(),
    });
  }

  void leaveSession(String sessionId) {
    send({
      'type': 'leave-session',
      'sessionId': sessionId,
    });
  }

  void send(Map<String, dynamic> jsonMap) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(jsonMap));
      } catch (e) {
        debugPrint('[Signaling] Send error: $e');
      }
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _onSessionCreatedController.close();
    _onConnectionRequestController.close();
    _onConnectionAcceptedController.close();
    _onConnectionRejectedController.close();
    _onReceiverAcceptedController.close();
    _onReceiverDisconnectedController.close();
    _onSessionClosedController.close();
    _onWebRtcOfferController.close();
    _onWebRtcAnswerController.close();
    _onIceCandidateController.close();
    _onAudioRelayController.close();
    _onMicRelayController.close();
    _onMicStateChangedController.close();
    _onAudioMessageController.close();
    _onErrorController.close();
  }
}
