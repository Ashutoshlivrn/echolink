import 'dart:convert';
import 'dart:typed_data';

class AudioMessage {
  final String id;
  final String senderId;
  final String senderName;
  final Uint8List audioData;
  final int durationMs;
  final DateTime timestamp;
  bool isPlaying;

  AudioMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.audioData,
    required this.durationMs,
    required this.timestamp,
    this.isPlaying = false,
  });

  factory AudioMessage.fromMap(Map<String, dynamic> map) {
    final base64Str = map['data'] as String? ?? '';
    final bytes = base64Decode(base64Str);
    return AudioMessage(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: map['senderId'] as String? ?? 'unknown',
      senderName: map['senderName'] as String? ?? 'Participant',
      audioData: bytes,
      durationMs: map['durationMs'] as int? ?? 1000,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'data': base64Encode(audioData),
      'durationMs': durationMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
