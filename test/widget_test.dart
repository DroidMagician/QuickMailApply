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
  });

  testWidgets('App loads home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickMailApplyApp());
    await tester.pumpAndSettle();

    expect(find.text('QuickMail Apply'), findsOneWidget);
    expect(find.text('Application profile'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
  });
}
