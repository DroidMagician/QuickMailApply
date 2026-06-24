import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quickmailapply/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream.empty(),
    );

    // Mock Google Sign-In MethodChannel to prevent test timeout
    const channel = MethodChannel('plugins.flutter.io/google_sign_in');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'init':
          return null;
        case 'signInSilently':
          return null;
        case 'isSignedIn':
          return false;
        default:
          return null;
      }
    });
  });

  testWidgets('App loads home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickMailApplyApp());
    await tester.pumpAndSettle();

    expect(find.text('QuickMail Apply'), findsOneWidget);
    expect(find.text('Application profile'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
  });
}
