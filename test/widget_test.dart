import 'package:flutter_test/flutter_test.dart';
import 'package:audio_sharing/app.dart';

void main() {
  testWidgets('Audio sharing app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AudioSharingApp());
    await tester.pump();

    // Verify app title exists
    expect(find.text('Shared Audio'), findsWidgets);
    expect(find.text('Start Sharing'), findsOneWidget);
    expect(find.text('Join Session'), findsOneWidget);
  });
}
