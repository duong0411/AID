import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'device_snapshot.dart';

class PracticeSession {
  PracticeSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.modeLabel,
    required this.sampleCount,
    required this.avgPulse,
    required this.maxPulse,
    required this.avgSpo2,
    required this.minSpo2,
    required this.maxForce,
    required this.maxPiezo,
    required this.alarmCount,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String modeLabel;
  final int sampleCount;
  final double avgPulse;
  final double maxPulse;
  final double avgSpo2;
  final double minSpo2;
  final double maxForce;
  final double maxPiezo;
  final int alarmCount;

  Duration get duration => endedAt.difference(startedAt);

  String get durationLabel {
    final s = duration.inSeconds.clamp(0, 86400);
    final m = s ~/ 60;
    final r = s % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      return '${h}g ${m % 60}p';
    }
    return '${m}p ${r}s';
  }

  String get timeLabel {
    final d = startedAt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${hh}h$mi';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'modeLabel': modeLabel,
        'sampleCount': sampleCount,
        'avgPulse': avgPulse,
        'maxPulse': maxPulse,
        'avgSpo2': avgSpo2,
        'minSpo2': minSpo2,
        'maxForce': maxForce,
        'maxPiezo': maxPiezo,
        'alarmCount': alarmCount,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      id: json['id']?.toString() ?? '',
      startedAt: DateTime.tryParse('${json['startedAt']}') ?? DateTime.now(),
      endedAt: DateTime.tryParse('${json['endedAt']}') ?? DateTime.now(),
      modeLabel: json['modeLabel']?.toString() ?? '',
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      avgPulse: (json['avgPulse'] as num?)?.toDouble() ?? 0,
      maxPulse: (json['maxPulse'] as num?)?.toDouble() ?? 0,
      avgSpo2: (json['avgSpo2'] as num?)?.toDouble() ?? 0,
      minSpo2: (json['minSpo2'] as num?)?.toDouble() ?? 0,
      maxForce: (json['maxForce'] as num?)?.toDouble() ?? 0,
      maxPiezo: (json['maxPiezo'] as num?)?.toDouble() ?? 0,
      alarmCount: (json['alarmCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PracticeAccumulator {
  DateTime startedAt = DateTime.now();
  int sampleCount = 0;
  int alarmCount = 0;
  double _sumPulse = 0;
  double _sumSpo2 = 0;
  int _pulseN = 0;
  int _spo2N = 0;
  double maxPulse = 0;
  double minSpo2 = 999;
  double maxForce = 0;
  double maxPiezo = 0;
  bool _wasAlarm = false;

  void add(DeviceSnapshot snap) {
    sampleCount++;
    if (snap.pulseBpm > 0) {
      _sumPulse += snap.pulseBpm;
      _pulseN++;
      if (snap.pulseBpm > maxPulse) maxPulse = snap.pulseBpm.toDouble();
    }
    if (snap.finger && snap.spo2 > 0) {
      _sumSpo2 += snap.spo2;
      _spo2N++;
      if (snap.spo2 < minSpo2) minSpo2 = snap.spo2;
    }
    if (snap.forcePct > maxForce) maxForce = snap.forcePct;
    if (snap.piezoPct > maxPiezo) maxPiezo = snap.piezoPct;
    if (snap.alarmActive && !_wasAlarm) alarmCount++;
    _wasAlarm = snap.alarmActive;
  }

  PracticeSession finish(String modeLabel) {
    final now = DateTime.now();
    return PracticeSession(
      id: now.millisecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: now,
      modeLabel: modeLabel,
      sampleCount: sampleCount,
      avgPulse: _pulseN == 0 ? 0 : _sumPulse / _pulseN,
      maxPulse: maxPulse,
      avgSpo2: _spo2N == 0 ? 0 : _sumSpo2 / _spo2N,
      minSpo2: minSpo2 >= 999 ? 0 : minSpo2,
      maxForce: maxForce,
      maxPiezo: maxPiezo,
      alarmCount: alarmCount,
    );
  }
}

class PracticeStore {
  Future<List<PracticeSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.practicePrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => PracticeSession.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PracticeSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await prefs.setString(AppConfig.practicePrefKey, encoded);
  }
}
