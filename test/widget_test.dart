import 'package:flutter_test/flutter_test.dart';

import 'package:aid_app/main.dart';

void main() {
  testWidgets('Man hinh AID mo duoc', (tester) async {
    await tester.pumpWidget(const AidApp(autoConnect: false));
    expect(find.text('AID'), findsOneWidget);
    expect(find.text('Chip ID'), findsOneWidget);
    expect(find.text('mqtt.duynguyen.io.vn'), findsOneWidget);
  });
}
