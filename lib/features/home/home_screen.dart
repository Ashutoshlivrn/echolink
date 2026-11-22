import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/session_controller.dart';
import '../feasibility/feasibility_screen.dart';
import '../receiver/receiver_screen.dart';
import '../sender/sender_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();
    final activeDevice = controller.activeAudioDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.spatial_audio_off_rounded),
            SizedBox(width: 8),
            Text('Shared Audio'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Title Card
            Container(
              padding: const EdgeInsets.all(22),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'REAL-TIME AUDIO SHARING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Listen to the same audio simultaneously.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stream playback audio from your phone directly to your friend\'s Bluetooth earphones with ultra-low latency WebRTC.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bluetooth & Audio Output Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: (activeDevice?.isBluetooth ?? false)
                      ? Colors.teal.shade300
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              color: (activeDevice?.isBluetooth ?? false)
                  ? Colors.teal.shade50.withValues(alpha: 0.5)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
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
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeDevice != null
                                ? activeDevice.name
                                : 'Built-in Speaker',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            (activeDevice?.isBluetooth ?? false)
                                ? 'Bluetooth Earphones Connected'
                                : 'Phone Speaker (Connect Bluetooth for best experience)',
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
            const SizedBox(height: 20),

            // Actions Grid / Buttons
            Row(
              children: [
                Expanded(
                  child: _buildRoleCard(
                    context,
                    title: 'Start Sharing',
                    subtitle: 'Transmitting phone\n(Host)',
                    icon: Icons.broadcast_on_personal_rounded,
                    color: theme.colorScheme.primary,
                    onTap: () async {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SenderScreen()),
                      );
                      await controller.startSharing();
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildRoleCard(
                    context,
                    title: 'Join Session',
                    subtitle: 'Receiving phone\n(Friend)',
                    icon: Icons.headphones_rounded,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceiverScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Feasibility & Compatibility Diagnostic Tool Button
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.amber.shade400, width: 1.5),
              ),
              color: Colors.amber.shade50.withValues(alpha: 0.6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(Icons.science_rounded, color: Colors.amber.shade900),
                ),
                title: const Text(
                  'Test Audio Capture Feasibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Test if Instagram, YouTube, or other apps allow audio capture on your device.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FeasibilityScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // How It Works Guide
            Text(
              'How It Works',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildGuideStep('1', 'Host starts sharing and receives a 6-letter Session ID or QR code.'),
            _buildGuideStep('2', 'Friend enters the code or scans the QR code to connect.'),
            _buildGuideStep('3', 'Host accepts the connection request.'),
            _buildGuideStep('4', 'Host continues watching video/audio. The exact audio plays in both Bluetooth earphones in real time!'),
          ],
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color,
              foregroundColor: Colors.white,
              radius: 22,
              child: Icon(icon, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
