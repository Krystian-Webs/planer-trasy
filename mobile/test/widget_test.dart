import 'package:flutter_test/flutter_test.dart';

import 'package:planer_trasy/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanerTrasyApp());
    await tester.pump();
  });
}
