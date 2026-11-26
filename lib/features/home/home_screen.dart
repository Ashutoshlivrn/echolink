import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/session_controller.dart';
import '../feasibility/feasibility_screen.dart';
import '../receiver/receiver_screen.dart';
import '../sender/sender_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWelcomeGuide = true;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _keyHero = GlobalKey();
  final GlobalKey _keyDeviceCard = GlobalKey();
  final GlobalKey _keyStartSharing = GlobalKey();
  final GlobalKey _keyJoinSession = GlobalKey();
  final GlobalKey _keyFeasibility = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTutorial();
      showTutorial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initTutorial() {
    List<TargetFocus> targets = [
      TargetFocus(
        identify: "hero",
        keyTarget: _keyHero,
        shape: ShapeLightFocus.RRect,
        radius: 24,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome to SyncAudio",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  "Stream system audio in real-time to your friend's Bluetooth earphones with zero perceptible delay.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "deviceCard",
        keyTarget: _keyDeviceCard,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Audio Output & Bluetooth",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  "Displays your connected Bluetooth earphones or phone speaker for shared audio output.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "startSharing",
        keyTarget: _keyStartSharing,
        shape: ShapeLightFocus.RRect,
        radius: 22,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Start Sharing (Host)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  "Tap here to stream media playing on your phone directly to your friend in real time.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "joinSession",
        keyTarget: _keyJoinSession,
        shape: ShapeLightFocus.RRect,
        radius: 22,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Join Session (Friend)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  "Tap here to connect to your friend's session using a 6-letter Session ID or QR code.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "feasibility",
        keyTarget: _keyFeasibility,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Feasibility Test",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  "Run this 10-second diagnostic tool to test audio capture compatibility with apps like YouTube & Instagram.",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      alignSkip: Alignment.topRight,
      textSkip: "SKIP TOUR",
      paddingFocus: 10,
      opacityShadow: 0.9, // Deep dimming (90% opacity) for high focus
      pulseEnable: true,
      onClickTarget: (target) {
        if (target.identify == "deviceCard" && _keyDeviceCard.currentContext != null) {
          Scrollable.ensureVisible(_keyDeviceCard.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.3);
        } else if (target.identify == "feasibility" && _keyFeasibility.currentContext != null) {
          Scrollable.ensureVisible(_keyFeasibility.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5);
        } else if (target.identify == "startSharing" && _keyStartSharing.currentContext != null) {
          Scrollable.ensureVisible(_keyStartSharing.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5);
        }
      },
      onFinish: () {},
      onSkip: () => true,
    );
  }

  void showTutorial() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    tutorialCoachMark?.show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();
    final activeDevice = controller.activeAudioDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.spatial_audio_rounded),
            SizedBox(width: 10),
            Text(
              'SyncAudio',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_rounded),
            tooltip: 'Take Interactive Tour',
            onPressed: showTutorial,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Audio Guide & FAQ',
            onPressed: () => _showFaqDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // First-Time Welcome Guide Banner
            if (_showWelcomeGuide) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waving_hand_rounded,
                            color: Color(0xFF6366F1), size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Welcome to SyncAudio!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              setState(() => _showWelcomeGuide = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share audio effortlessly between two phones:\n'
                      '• Tap **Start Sharing** if you are playing audio (Host).\n'
                      '• Tap **Join Session** if you want to listen along (Friend).',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Hero Banner Card with Showcase Key
            KeyedSubtree(
              key: _keyHero,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PRO EDITION • P2P WEBRTC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Icon(Icons.verified_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Listen together, in real time.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stream system audio from your phone directly to your friend\'s Bluetooth earphones with zero perceptible delay.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Audio Specs & Quality Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSpecItem(Icons.high_quality_rounded, '48 kHz', 'Sample Rate'),
                  Container(width: 1, height: 28, color: Colors.grey.shade400),
                  _buildSpecItem(Icons.surround_sound_rounded, '16-Bit', 'Stereo PCM'),
                  Container(width: 1, height: 28, color: Colors.grey.shade400),
                  _buildSpecItem(Icons.bolt_rounded, '< 30ms', 'Ultra-Low Latency'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bluetooth & Audio Output Status Card with Showcase Key
            KeyedSubtree(
              key: _keyDeviceCard,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: (activeDevice?.isBluetooth ?? false)
                        ? Colors.teal.shade300
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                color: (activeDevice?.isBluetooth ?? false)
                    ? Colors.teal.shade50.withValues(alpha: 0.6)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: (activeDevice?.isBluetooth ?? false)
                            ? Colors.teal.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          (activeDevice?.isBluetooth ?? false)
                              ? Icons.bluetooth_audio_rounded
                              : Icons.volume_up_rounded,
                          color: (activeDevice?.isBluetooth ?? false)
                              ? Colors.teal.shade800
                              : Colors.grey.shade700,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeDevice != null
                                  ? activeDevice.name
                                  : 'Phone Speaker',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (activeDevice?.isBluetooth ?? false)
                                  ? 'Bluetooth Earphones Active'
                                  : 'Built-in Speaker (Connect Bluetooth for shared listening)',
                              style: TextStyle(
                                color: (activeDevice?.isBluetooth ?? false)
                                    ? Colors.teal.shade900
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Audio Devices',
                        onPressed: () => controller.refreshDevices(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selection Grid (Start Sharing vs Join Session)
            Text(
              'Select Your Role',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: _keyStartSharing,
                    child: _buildRoleCard(
                      context,
                      title: 'Start Sharing',
                      subtitle: 'Play & transmit\n(Host)',
                      icon: Icons.broadcast_on_personal_rounded,
                      color: theme.colorScheme.primary,
                      onTap: () async {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SenderScreen(),
                          ),
                        );
                        await controller.startSharing();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KeyedSubtree(
                    key: _keyJoinSession,
                    child: _buildRoleCard(
                      context,
                      title: 'Join Session',
                      subtitle: 'Listen live\n(Friend)',
                      icon: Icons.headphones_rounded,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReceiverScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Feasibility & Compatibility Diagnostic Tool with Showcase Key
            KeyedSubtree(
              key: _keyFeasibility,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.amber.shade400, width: 1.5),
                ),
                color: Colors.amber.shade50.withValues(alpha: 0.7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FeasibilityScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amber.shade200,
                          child: Icon(Icons.science_rounded,
                              color: Colors.amber.shade900),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Test Audio Capture Feasibility',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Verify if apps like YouTube & Instagram allow audio capture on your device.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Guide Section
            Text(
              'How It Works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _buildGuideStep(
                '1', 'Host starts sharing and gets a 6-letter Session ID or QR code.'),
            _buildGuideStep(
                '2', 'Friend enters the Session ID or scans the QR code.'),
            _buildGuideStep('3', 'Host accepts the incoming connection request.'),
            _buildGuideStep(
                '4', 'Enjoy synchronized crystal-clear audio in both earphones!'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: Colors.white,
                radius: 24,
                child: Icon(icon, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('SyncAudio FAQ'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• Why do I need Bluetooth earphones?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'For shared listening without acoustic echo, both you and your friend should wear separate Bluetooth earphones/headsets.\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Can I use Instagram Reels?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Some apps like Instagram enforce copyright capture restrictions (ALLOW_CAPTURE_BY_NONE). Use our Feasibility Test tool to check compatibility.\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Does it work in background?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• Yes! The app runs a Media Playback Foreground Service so audio continues smoothly when you lock your screen or switch apps.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
