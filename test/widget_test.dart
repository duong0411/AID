import 'package:aid_app/aid_models.dart';
import 'package:aid_app/home_page.dart';
import 'package:aid_app/main.dart';
import 'package:aid_app/mqtt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Man hinh mo bang thong so cam bien', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const AidApp(autoConnect: false));
    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('Lực'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Điện thế'), 300);
    expect(find.text('SpO2'), findsOneWidget);
    expect(find.text('Điện thế'), findsOneWidget);
  });

  testWidgets('Co du lieu thi hien so do', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AidController(autoConnect: false);
    controller.preview(_sample());
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: HomePage(controller: controller),
    ));
    expect(find.text('72'), findsOneWidget);
    expect(find.text('CANH BAO LUC'), findsWidgets);
    await tester.scrollUntilVisible(find.text('98'), 300);
    expect(find.text('98'), findsOneWidget);
    controller.dispose();
  });
}

AidSnapshot _sample() {
  return AidSnapshot(
    id: 'A1B2C3',
    screen: 0,
    title: '1. A1B2C3',
    badge: '[!]',
    alarm: true,
    reason: 'CANH BAO LUC',
    mute: false,
    buzzerOn: true,
    editing: false,
    cursor: 0,
    hr: 72,
    hrAdc: 1800,
    force: 80,
    grams: 400,
    spo2: 98,
    spo2Hr: 70,
    maxOnline: true,
    finger: true,
    piezo: 12,
    volt: 0.4,
    alarmHr: false,
    alarmForce: true,
    alarmSpo2: false,
    alarmPiezo: false,
    forceMax: 60,
    hrMin: 50,
    hrMax: 120,
    spo2Min: 92,
    piezoMax: 50,
    wifi: true,
    mqtt: true,
    rssi: -48,
    ip: '192.168.1.20',
    wave: const [],
    at: DateTime.now(),
  );
}
