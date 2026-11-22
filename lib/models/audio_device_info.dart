class AudioDeviceInfo {
  final int id;
  final String name;
  final String type;
  final bool isBluetooth;
  final List<int> sampleRates;

  const AudioDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.isBluetooth,
    required this.sampleRates,
  });

  factory AudioDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return AudioDeviceInfo(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? 'Audio Output',
      type: map['type'] as String? ?? 'Speaker',
      isBluetooth: map['isBluetooth'] as bool? ?? false,
      sampleRates: (map['sampleRates'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }

  @override
  String toString() => '$name ($type)';
}
