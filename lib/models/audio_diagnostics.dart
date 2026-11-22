class AudioDiagnostics {
  final double rmsDb;
  final int peakAmplitude;
  final bool isSilence;
  final int bytesPerSecond;
  final int totalBytes;
  final DateTime timestamp;

  AudioDiagnostics({
    required this.rmsDb,
    required this.peakAmplitude,
    required this.isSilence,
    required this.bytesPerSecond,
    required this.totalBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AudioDiagnostics.fromMap(Map<dynamic, dynamic> map) {
    return AudioDiagnostics(
      rmsDb: (map['rmsDb'] as num?)?.toDouble() ?? -90.0,
      peakAmplitude: (map['peakAmplitude'] as num?)?.toInt() ?? 0,
      isSilence: map['isSilence'] as bool? ?? true,
      bytesPerSecond: (map['bytesPerSecond'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
    );
  }

  factory AudioDiagnostics.empty() {
    return AudioDiagnostics(
      rmsDb: -90.0,
      peakAmplitude: 0,
      isSilence: true,
      bytesPerSecond: 0,
      totalBytes: 0,
    );
  }
}
