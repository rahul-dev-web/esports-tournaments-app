import 'package:flutter_test/flutter_test.dart';
import 'package:arenahub_mobile/main.dart';

void main() {
  testWidgets('shows the ArenaHub home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ArenaHubApp());
    expect(find.text('ArenaHub'), findsOneWidget);
    expect(find.text('Compete. Team up. Win.'), findsOneWidget);
  });
}
