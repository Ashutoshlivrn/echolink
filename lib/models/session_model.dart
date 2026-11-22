enum SessionRole { sender, receiver }

enum SessionState {
  idle,
  connecting,
  waitingApproval,
  ready,
  streaming,
  disconnected,
  error,
}

enum ParticipantStatus {
  pending,
  accepted,
  rejected,
  disconnected,
}

class Participant {
  final String id;
  final String name;
  ParticipantStatus status;
  final DateTime joinedAt;

  Participant({
    required this.id,
    required this.name,
    this.status = ParticipantStatus.pending,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Friend Device',
      status: _parseStatus(map['status']),
    );
  }

  static ParticipantStatus _parseStatus(dynamic status) {
    switch (status) {
      case 'accepted':
        return ParticipantStatus.accepted;
      case 'rejected':
        return ParticipantStatus.rejected;
      case 'disconnected':
        return ParticipantStatus.disconnected;
      default:
        return ParticipantStatus.pending;
    }
  }
}

class ConnectionStats {
  final int latencyMs;
  final double packetLoss;
  final String transport;
  final int bytesReceived;
  final int bytesSent;

  const ConnectionStats({
    this.latencyMs = 0,
    this.packetLoss = 0.0,
    this.transport = 'WebRTC Direct P2P',
    this.bytesReceived = 0,
    this.bytesSent = 0,
  });
}
