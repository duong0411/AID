class AidSnapshot {
  AidSnapshot({
    required this.id,
    required this.screen,
    required this.title,
    required this.badge,
    required this.alarm,
    required this.reason,
    required this.mute,
    required this.buzzerOn,
    required this.editing,
    required this.cursor,
    required this.hr,
    required this.hrAdc,
    required this.force,
    required this.grams,
    required this.spo2,
    required this.spo2Hr,
    required this.maxOnline,
    required this.finger,
    required this.piezo,
    required this.volt,
    required this.alarmHr,
    required this.alarmForce,
    required this.alarmSpo2,
    required this.alarmPiezo,
    required this.forceMax,
    required this.hrMin,
    required this.hrMax,
    required this.spo2Min,
    required this.piezoMax,
    required this.wifi,
    required this.mqtt,
    required this.rssi,
    required this.ip,
    required this.wave,
    required this.at,
  });

  final String id;
  final int screen;
  final String title;
  final String badge;
  final bool alarm;
  final String reason;
  final bool mute;
  final bool buzzerOn;
  final bool editing;
  final int cursor;
  final int hr;
  final int hrAdc;
  final double force;
  final double grams;
  final double spo2;
  final double spo2Hr;
  final bool maxOnline;
  final bool finger;
  final double piezo;
  final double volt;
  final bool alarmHr;
  final bool alarmForce;
  final bool alarmSpo2;
  final bool alarmPiezo;
  final int forceMax;
  final int hrMin;
  final int hrMax;
  final int spo2Min;
  final int piezoMax;
  final bool wifi;
  final bool mqtt;
  final int rssi;
  final String ip;
  final List<int> wave;
  final DateTime at;

  static AidSnapshot? fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    return AidSnapshot(
      id: id.toUpperCase(),
      screen: _i(json['screen']).clamp(0, 5),
      title: '${json['title'] ?? ''}',
      badge: '${json['badge'] ?? ''}',
      alarm: _b(json['alarm']),
      reason: '${json['reason'] ?? ''}',
      mute: _b(json['mute']),
      buzzerOn: _b(json['bz']),
      editing: _b(json['edit']),
      cursor: _i(json['cursor']).clamp(0, 5),
      hr: _i(json['hr']),
      hrAdc: _i(json['hrAdc']),
      force: _d(json['force']),
      grams: _d(json['grams']),
      spo2: _d(json['spo2']),
      spo2Hr: _d(json['spo2hr']),
      maxOnline: _b(json['maxOk']),
      finger: _b(json['finger']),
      piezo: _d(json['piezo']),
      volt: _d(json['volt']),
      alarmHr: _b(json['aHr']),
      alarmForce: _b(json['aF']),
      alarmSpo2: _b(json['aO2']),
      alarmPiezo: _b(json['aPz']),
      forceMax: _i(json['fMax']),
      hrMin: _i(json['hrMin']),
      hrMax: _i(json['hrMax']),
      spo2Min: _i(json['o2Min']),
      piezoMax: _i(json['pMax']),
      wifi: _b(json['wifi']),
      mqtt: _b(json['mqtt']),
      rssi: _i(json['rssi']),
      ip: '${json['ip'] ?? ''}',
      wave: _wave(json['w']),
      at: DateTime.now(),
    );
  }

  String get screenName {
    const names = [
      'Tong quan',
      'Nhip tim',
      'Cam bien luc',
      'Oxy mau',
      'Dien the',
      'Cai dat',
    ];
    return names[screen.clamp(0, 5)];
  }
}

int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('$v') ?? 0;
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '$v'.toLowerCase();
  return s == '1' || s == 'true' || s == 'on';
}

List<int> _wave(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => _i(e)).toList();
}

const oledScreenTitles = [
  '1. TONG QUAN',
  '2. NHIP TIM (PULSE)',
  '3. CAM BIEN LUC',
  '4. OXY MAU (SPO2)',
  '5. DIEN THE (PIEZO)',
  '6. CAI DAT NGUONG',
];
