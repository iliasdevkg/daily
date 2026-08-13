import 'package:flutter_test/flutter_test.dart';
import 'package:esy_delivery_app/main.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const EsyApp());
    expect(find.byType(EsyApp), findsOneWidget);
  });
}
