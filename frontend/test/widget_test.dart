import 'package:flutter_test/flutter_test.dart';
import 'package:codertalk/main.dart';

void main() {
  testWidgets('CoderTalk app initializes', (WidgetTester tester) async {
    // Basic initialization test
    await tester.pumpWidget(const CoderTalkApp());
    expect(find.byType(CoderTalkApp), findsOneWidget);
  });
}
