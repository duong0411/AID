class DeviceSnapshot {
  const DeviceSnapshot({
    required this.uptime,
    required this.screen,
    required this.pulseBpm,
    required this.pulseRaw,
    required this.beat,
    required this.forcePct,
    required this.forceGrams,
    required this.spo2,
    required this.spo2Bpm,
    required this.finger,
    required this.maxOnline,
    required this.piezoPct,
    required this.piezoVolts,
    required this.alarmActive,
    required this.alarmPulse,
    required this.alarmForce,
    required this.alarmSpo2,
    required this.alarmPiezo,
    required this.alarmReason,
    required this.buzzerEnabled,
    required this.buzzerMuted,
    required this.forceThresh,
    required this.pulseMin,
    required this.pulseMax,
    required this.spo2Min,
    required this.piezoThresh,
  });

  final int uptime;
  final int screen;
  final int pulseBpm;
  final int pulseRaw;
  final bool beat;
  final double forcePct;
  final double forceGrams;
  final double spo2;
  final double spo2Bpm;
  final bool finger;
  final bool maxOnline;
  final double piezoPct;
  final double piezoVolts;
  final bool alarmActive;
  final bool alarmPulse;
  final bool alarmForce;
  final bool alarmSpo2;
  final bool alarmPiezo;
  final String alarmReason;
  final bool buzzerEnabled;
  final bool buzzerMuted;
  final int forceThresh;
  final int pulseMin;
  final int pulseMax;
  final int spo2Min;
  final int piezoThresh;

  factory DeviceSnapshot.fromJson(Map<String, dynamic> json) {
    final pulse = _map(json['pulse']);
    final force = _map(json['force']);
    final spo2 = _map(json['spo2']);
    final piezo = _map(json['piezo']);
    final alarm = _map(json['alarm']);
    final buzzer = _map(json['buzzer']);
    final settings = _map(json['settings']);

    return DeviceSnapshot(
      uptime: _int(json['uptime']),
      screen: _int(json['screen']),
      pulseBpm: _int(pulse['bpm']),
      pulseRaw: _int(pulse['raw']),
      beat: _bool(pulse['beat']),
      forcePct: _double(force['pct']),
      forceGrams: _double(force['grams']),
      spo2: _double(spo2['spo2']),
      spo2Bpm: _double(spo2['bpm']),
      finger: _bool(spo2['finger']),
      maxOnline: _bool(spo2['online']),
      piezoPct: _double(piezo['pct']),
      piezoVolts: _double(piezo['volts']),
      alarmActive: _bool(alarm['active']),
      alarmPulse: _bool(alarm['pulse']),
      alarmForce: _bool(alarm['force']),
      alarmSpo2: _bool(alarm['spo2']),
      alarmPiezo: _bool(alarm['piezo']),
      alarmReason: alarm['reason']?.toString() ?? '',
      buzzerEnabled: _bool(buzzer['enabled']),
      buzzerMuted: _bool(buzzer['muted']),
      forceThresh: _int(settings['forceThresh']),
      pulseMin: _int(settings['pulseMin']),
      pulseMax: _int(settings['pulseMax']),
      spo2Min: _int(settings['spo2Min']),
      piezoThresh: _int(settings['piezoThresh']),
    );
  }

  String get alarmLabel {
    switch (alarmReason.trim()) {
      case 'LUC VUOT NGUONG!':
        return 'Lực ép vượt ngưỡng';
      case 'NHIP TIM QUA CAO!':
        return 'Nhịp tim quá cao';
      case 'NHIP TIM QUA THAP!':
        return 'Nhịp tim quá thấp';
      case 'THIEU OXY (SPO2 THAP)!':
        return 'Thiếu oxy (SpO2 thấp)';
      case 'RUNG/XUNG QUA NGUONG!':
        return 'Rung / xung quá ngưỡng';
      default:
        return alarmReason.trim().isEmpty ? 'Có cảnh báo' : alarmReason.trim();
    }
  }
}

class SamplePoint {
  SamplePoint({
    required this.pulseBpm,
    required this.spo2,
    required this.forcePct,
    required this.piezoPct,
  });

  final double pulseBpm;
  final double spo2;
  final double forcePct;
  final double piezoPct;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return {};
}

int _int(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1';
}
