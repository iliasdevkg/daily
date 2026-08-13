import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_picker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PickerApp());
  });
}
