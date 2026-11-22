import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/audio_device_info.dart';
import '../models/audio_diagnostics.dart';

class NativeAudioService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.audio_sharing/audio_control');

  static const EventChannel _audioStreamChannel =
      EventChannel('com.example.audio_sharing/audio_stream');

  static const EventChannel _diagnosticsStreamChannel =
      EventChannel('com.example.audio_sharing/diagnostics_stream');

  static const EventChannel _deviceStreamChannel =
      EventChannel('com.example.audio_sharing/device_stream');

  StreamSubscription? _audioSubscription;
  StreamSubscription? _diagnosticsSubscription;
  StreamSubscription? _deviceSubscription;

  final _audioChunkController = StreamController<Uint8List>.broadcast();
  final _diagnosticsController = StreamController<AudioDiagnostics>.broadcast();
  final _devicesController = StreamController<List<AudioDeviceInfo>>.broadcast();

  Stream<Uint8List> get audioStream => _audioChunkController.stream;
  Stream<AudioDiagnostics> get diagnosticsStream => _diagnosticsController.stream;
  Stream<List<AudioDeviceInfo>> get devicesStream => _devicesController.stream;

  NativeAudioService() {
    _initEventChannels();
  }

  void _initEventChannels() {
    _audioSubscription = _audioStreamChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Uint8List) {
          _audioChunkController.add(event);
        } else if (event is List<dynamic>) {
          _audioChunkController.add(Uint8List.fromList(event.cast<int>()));
        }
      },
      onError: (dynamic error) {
        debugPrint('[NativeAudioService] Audio stream error: $error');
      },
    );

    _diagnosticsSubscription =
        _diagnosticsStreamChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          _diagnosticsController.add(AudioDiagnostics.fromMap(event));
        }
      },
      onError: (dynamic error) {
        debugPrint('[NativeAudioService] Diagnostics stream error: $error');
      },
    );

    _deviceSubscription = _deviceStreamChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is List) {
          final list = event
              .whereType<Map>()
              .map((map) => AudioDeviceInfo.fromMap(map))
              .toList();
          _devicesController.add(list);
        }
      },
      onError: (dynamic error) {
        debugPrint('[NativeAudioService] Device stream error: $error');
      },
    );
  }

  /// Request MediaProjection and begin capturing system playback audio.
  /// Android prompts the user with the screen/audio capture dialog.
  Future<bool> startAudioCapture({
    int sampleRate = 48000,
    int channels = 2,
  }) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>(
        'startAudioCapture',
        {'sampleRate': sampleRate, 'channels': channels},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[NativeAudioService] Start capture error: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Stop system audio playback capture and terminate the foreground service.
  Future<bool> stopAudioCapture() async {
    try {
      final bool? success =
          await _methodChannel.invokeMethod<bool>('stopAudioCapture');
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[NativeAudioService] Stop capture error: $e');
      return false;
    }
  }

  Future<bool> isCapturing() async {
    try {
      final bool? active = await _methodChannel.invokeMethod<bool>('isCapturing');
      return active ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start the receiver's low-latency native AudioTrack.
  Future<bool> startAudioPlayer({
    int sampleRate = 48000,
    int channels = 2,
  }) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>(
        'startAudioPlayer',
        {'sampleRate': sampleRate, 'channels': channels},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[NativeAudioService] Start player error: $e');
      return false;
    }
  }

  /// Write a raw PCM chunk to the receiver's AudioTrack.
  Future<int> writeAudioChunk(Uint8List data) async {
    try {
      final int? written = await _methodChannel.invokeMethod<int>(
        'writeAudioChunk',
        {'data': data},
      );
      return written ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Stop the receiver's AudioTrack.
  Future<bool> stopAudioPlayer() async {
    try {
      final bool? success =
          await _methodChannel.invokeMethod<bool>('stopAudioPlayer');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Set the playback volume (0.0 to 1.0).
  Future<bool> setPlayerVolume(double volume) async {
    try {
      final bool? success = await _methodChannel.invokeMethod<bool>(
        'setPlayerVolume',
        {'volume': volume.clamp(0.0, 1.0)},
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Query the currently connected audio outputs (Bluetooth earphones, etc.).
  Future<List<AudioDeviceInfo>> getAudioDevices() async {
    try {
      final List<dynamic>? raw =
          await _methodChannel.invokeMethod<List<dynamic>>('getAudioDevices');
      if (raw != null) {
        return raw
            .whereType<Map>()
            .map((map) => AudioDeviceInfo.fromMap(map))
            .toList();
      }
    } catch (e) {
      debugPrint('[NativeAudioService] Error getting devices: $e');
    }
    return [];
  }

  void dispose() {
    _audioSubscription?.cancel();
    _diagnosticsSubscription?.cancel();
    _deviceSubscription?.cancel();
    _audioChunkController.close();
    _diagnosticsController.close();
    _devicesController.close();
  }
}
