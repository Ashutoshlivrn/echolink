import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/session_controller.dart';
import '../../widgets/audio_meter.dart';
import '../../widgets/custom_button.dart';

class FeasibilityScreen extends StatefulWidget {
  const FeasibilityScreen({super.key});

  @override
  State<FeasibilityScreen> createState() => _FeasibilityScreenState();
}

class _FeasibilityScreenState extends State<FeasibilityScreen> {
  bool _isTesting = false;
  int _countdown = 10;
  Timer? _timer;
  StreamSubscription? _diagSub;

  int _peakObserved = 0;
  double _maxRms = -90.0;
  int _totalBytesObserved = 0;
  String? _testVerdict;
  Color _verdictColor = Colors.grey;

  @override
  void dispose() {
    _timer?.cancel();
    _diagSub?.cancel();
    super.dispose();
  }

  void _startCompatibilityTest(SessionController controller) async {
    setState(() {
      _isTesting = true;
      _countdown = 10;
      _peakObserved = 0;
      _maxRms = -90.0;
      _totalBytesObserved = 0;
      _testVerdict = null;
    });

    final started = await controller.nativeAudio.startAudioCapture();
    if (!started) {
      setState(() {
        _isTesting = false;
        _testVerdict =
            'Permission was not granted or MediaProjection was cancelled. '
            'Please accept the capture prompt to run the test.';
        _verdictColor = Colors.red;
      });
      return;
    }

    _diagSub?.cancel();
    _diagSub = controller.nativeAudio.diagnosticsStream.listen((diag) {
      if (!_isTesting) return;
      _totalBytesObserved = diag.totalBytes;
      if (diag.peakAmplitude > _peakObserved) {
        _peakObserved = diag.peakAmplitude;
      }
      if (diag.rmsDb > _maxRms) {
        _maxRms = diag.rmsDb;
      }
      setState(() {});
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        _diagSub?.cancel();
        await controller.nativeAudio.stopAudioCapture();

        setState(() {
          _isTesting = false;
          _evaluateVerdict();
        });
      }
    });
  }

  void _evaluateVerdict() {
    if (_totalBytesObserved == 0) {
      _testVerdict =
          'FAILED: No audio bytes were received from the AudioRecord stream. '
          'Android AudioPlaybackCapture was unable to start.';
      _verdictColor = Colors.red;
    } else if (_peakObserved > 300 && _maxRms > -50.0) {
      _testVerdict =
          'SUCCESSFUL CAPTURE (ALLOWED) 🎉\n'
          'Live audio was captured with Peak Amplitude = $_peakObserved '
          'and Max RMS = ${_maxRms.toStringAsFixed(1)} dBFS.\n'
          'The currently playing application explicitly permits audio playback capture.';
      _verdictColor = Colors.green;
    } else {
      _testVerdict =
          'SILENCE DETECTED (RESTRICTED) ⚠️\n'
          'Bytes were captured ($_totalBytesObserved bytes), but the samples were pure silence '
          '(Peak = $_peakObserved, RMS = ${_maxRms.toStringAsFixed(1)} dBFS).\n\n'
          'Explanation:\n'
          'Android 10+ AudioPlaybackCapture enforces app-level capture policy. '
          'Meta (Instagram / Facebook) specifically sets ALLOW_CAPTURE_BY_NONE on Reels & Stories '
          'to protect licensed music.\n\n'
          'Compatible sources: Web browsers playing YouTube/audio, open media players, VLC, games, '
          'and apps that do not opt out of capture.';
      _verdictColor = Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Capture Feasibility & Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Architectural Card
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.policy_rounded,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Android Capture Policy Analysis',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Android 10 (API 29) introduced AudioPlaybackCaptureConfiguration to record system audio without modifying the source app. However, Android enforces three rules:\n\n'
                      '1. Default Policy: Apps targeting Android 10+ allow capture by default unless explicitly disabled.\n'
                      '2. Opt-out: Apps can set android:allowAudioPlaybackCapture="false" or AudioAttributes.ALLOW_CAPTURE_BY_NONE in code.\n'
                      '3. Instagram Reels: Instagram uses ExoPlayer with ALLOW_CAPTURE_BY_NONE on Reels to protect copyrighted music.\n\n'
                      'When an app blocks capture, Android silently returns zeroes (silence) for that stream while audio continues playing in your earphones.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Test Area
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '10-Second Compatibility Diagnostic Test',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Instructions:\n'
                      '1. Start playing audio on your phone (e.g. Instagram Reel, YouTube in Chrome, Spotify, or a game).\n'
                      '2. Tap "Start 10s Diagnostic" below and allow screen/audio permission.\n'
                      '3. The app will capture audio for 10 seconds and report whether active audio or silence is produced.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    AudioMeterWidget(
                      rmsDb: controller.diagnostics.rmsDb,
                      peakAmplitude: controller.diagnostics.peakAmplitude,
                      isSilence: controller.diagnostics.isSilence,
                      bytesPerSec: controller.diagnostics.bytesPerSecond,
                      isCapturing: _isTesting,
                    ),
                    const SizedBox(height: 16),

                    if (_isTesting) ...[
                      LinearProgressIndicator(
                        value: (10 - _countdown) / 10.0,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Testing... $_countdown seconds remaining\n'
                          'Switch to your media app now to test!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    CustomButton(
                      text: _isTesting ? 'Testing in progress...' : 'Start 10s Diagnostic',
                      icon: Icons.play_arrow_rounded,
                      isLoading: _isTesting,
                      onPressed: _isTesting
                          ? null
                          : () => _startCompatibilityTest(controller),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Diagnostic Verdict Card
            if (_testVerdict != null) ...[
              Card(
                elevation: 1,
                color: _verdictColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _verdictColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _verdictColor == Colors.green
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: _verdictColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Test Diagnostic Result',
                            style: TextStyle(
                              color: _verdictColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _testVerdict!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Supported Apps Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tested Apps Compatibility Reference',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAppRow('Chrome / Firefox (Web Videos)', 'Supported (Full Audio)', Colors.green),
                    _buildAppRow('YouTube Web / Mobile Site', 'Supported (Full Audio)', Colors.green),
                    _buildAppRow('VLC / Local Media Players', 'Supported (Full Audio)', Colors.green),
                    _buildAppRow('Mobile Games (Unity/Unreal)', 'Supported (Full Audio)', Colors.green),
                    _buildAppRow('Podcast Addict / AntennaPod', 'Supported (Full Audio)', Colors.green),
                    _buildAppRow('Instagram Reels & Stories', 'Restricted by Meta Policy', Colors.orange),
                    _buildAppRow('Netflix / Disney+ (DRM)', 'Restricted by Widevine DRM', Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppRow(String app, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(app, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(
            status,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
