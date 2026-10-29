import 'package:flutter_test/flutter_test.dart';
import 'package:smart_first_aid_app/core/config.dart';
import 'package:smart_first_aid_app/core/device_api.dart';
import 'package:smart_first_aid_app/core/device_snapshot.dart';
import 'package:smart_first_aid_app/core/monitor_provider.dart';
import 'package:smart_first_aid_app/core/practice_session.dart';

void main() {
  test('default host and MQTT chip match firmware', () {
    expect(AppConfig.defaultHost, '192.168.4.1');
    expect(AppConfig.defaultChipId, '777');
    expect(AppConfig.brokerUrl, 'wss://mqtt.duynguyen.io.vn/mqtt');
    AppConfig.setChipId('777');
    expect(AppConfig.topicVitals, 'tele/777_vitals/status');
    expect(AppConfig.cmndMute, 'cmnd/777_mute/POWER');
  });

  test('snapshot parses the firmware /api/data payload', () {
    final snap = DeviceSnapshot.fromJson({
      'uptime': 12,
      'screen': 0,
      'pulse': {'bpm': 76, 'raw': 1800, 'filtered': 1750, 'beat': true},
      'force': {'pct': 22.5, 'grams': 400, 'raw': 900},
      'spo2': {'spo2': 97, 'bpm': 75, 'finger': true, 'online': true},
      'piezo': {'pct': 8.0, 'volts': 0.12, 'raw': 40},
      'alarm': {
        'active': true,
        'pulse': false,
        'force': false,
        'spo2': true,
        'piezo': false,
        'reason': 'THIEU OXY (SPO2 THAP)!',
      },
      'buzzer': {'enabled': true, 'muted': false},
      'settings': {
        'forceThresh': 60,
        'pulseMin': 50,
        'pulseMax': 120,
        'spo2Min': 92,
        'piezoThresh': 50,
        'buzzerEn': true,
      },
    });

    expect(snap.pulseBpm, 76);
    expect(snap.spo2, 97);
    expect(snap.alarmLabel, 'Thiếu oxy (SpO2 thấp)');
  });

  test('provider stays on the connect screen until the device answers', () {
    final provider = MonitorProvider(
      api: _FakeApi(),
      hosts: _MemoryHosts(),
    );
    expect(provider.canEnterSystem, isFalse);
    expect(provider.host, AppConfig.defaultHost);
    provider.dispose();
  });

  test('practice accumulator summarizes a measurement round', () {
    final acc = PracticeAccumulator()..startedAt = DateTime(2026, 10, 27, 21);
    acc.add(
      DeviceSnapshot.fromJson({
        'uptime': 1,
        'screen': 0,
        'pulse': {'bpm': 80, 'raw': 1, 'filtered': 1, 'beat': false},
        'force': {'pct': 10, 'grams': 1, 'raw': 1},
        'spo2': {'spo2': 96, 'bpm': 80, 'finger': true, 'online': true},
        'piezo': {'pct': 5, 'volts': 0.1, 'raw': 1},
        'alarm': {
          'active': false,
          'pulse': false,
          'force': false,
          'spo2': false,
          'piezo': false,
          'reason': '',
        },
        'buzzer': {'enabled': true, 'muted': false},
        'settings': {
          'forceThresh': 60,
          'pulseMin': 50,
          'pulseMax': 120,
          'spo2Min': 92,
          'piezoThresh': 50,
          'buzzerEn': true,
        },
      }),
    );
    acc.add(
      DeviceSnapshot.fromJson({
        'uptime': 2,
        'screen': 0,
        'pulse': {'bpm': 100, 'raw': 1, 'filtered': 1, 'beat': false},
        'force': {'pct': 40, 'grams': 1, 'raw': 1},
        'spo2': {'spo2': 90, 'bpm': 100, 'finger': true, 'online': true},
        'piezo': {'pct': 20, 'volts': 0.2, 'raw': 1},
        'alarm': {
          'active': true,
          'pulse': false,
          'force': false,
          'spo2': true,
          'piezo': false,
          'reason': 'THIEU OXY (SPO2 THAP)!',
        },
        'buzzer': {'enabled': true, 'muted': false},
        'settings': {
          'forceThresh': 60,
          'pulseMin': 50,
          'pulseMax': 120,
          'spo2Min': 92,
          'piezoThresh': 50,
          'buzzerEn': true,
        },
      }),
    );
    final session = acc.finish('Từ xa · chip 777');
    expect(session.sampleCount, 2);
    expect(session.avgPulse, 90);
    expect(session.maxPulse, 100);
    expect(session.minSpo2, 90);
    expect(session.maxForce, 40);
    expect(session.alarmCount, 1);
  });
}

class _FakeApi implements AidClient {
  @override
  Future<DeviceSnapshot> fetchData(String host) async {
    throw DeviceException('offline');
  }

  @override
  Future<Map<String, dynamic>> postAction(
    String host,
    String action, {
    String? value,
  }) async {
    return {'status': 'ok'};
  }

  @override
  Future<void> postSettings(String host, Map<String, String> fields) async {}
}

class _MemoryHosts implements HostStore {
  String? host;
  String? chip;
  ConnectMode mode = ConnectMode.mqtt;

  @override
  Future<String?> readHost() async => host;

  @override
  Future<void> writeHost(String value) async => host = value;

  @override
  Future<String?> readChip() async => chip;

  @override
  Future<void> writeChip(String value) async => chip = value;

  @override
  Future<ConnectMode> readMode() async => mode;

  @override
  Future<void> writeMode(ConnectMode value) async => mode = value;
}
