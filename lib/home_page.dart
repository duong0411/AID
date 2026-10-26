import 'package:flutter/material.dart';

import 'aid_models.dart';
import 'mqtt_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final AidController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _chip = TextEditingController();

  AidController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onDevice);
    _chip.text = c.chipId;
  }

  @override
  void dispose() {
    c.removeListener(_onDevice);
    _chip.dispose();
    super.dispose();
  }

  void _onDevice() {
    if (!mounted) return;
    if (_chip.text.isEmpty && c.chipId.isNotEmpty) _chip.text = c.chipId;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snap = c.snapshot;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _topBar(snap),
            const SizedBox(height: 14),
            if (snap != null && snap.alarm) ...[
              _alarmBanner(snap),
              const SizedBox(height: 12),
            ],
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: [
                _SensorCard(
                  title: 'Nhịp tim',
                  value: snap == null || snap.hr <= 0 ? '--' : '${snap.hr}',
                  unit: 'bpm',
                  detail: snap == null
                      ? 'Ngưỡng 50–120'
                      : 'ADC ${snap.hrAdc} · ngưỡng ${snap.hrMin}–${snap.hrMax}',
                  status: _hrStatus(snap),
                  alarm: snap?.alarmHr ?? false,
                  color: const Color(0xFFFF6B7A),
                  icon: Icons.favorite_rounded,
                  fraction: snap == null || snap.hr <= 0 ? 0 : (snap.hr / 180).clamp(0, 1),
                  samples: c.hrTrace,
                ),
                _SensorCard(
                  title: 'Lực',
                  value: snap == null ? '--' : snap.force.toStringAsFixed(0),
                  unit: '%',
                  detail: snap == null
                      ? 'Ngưỡng 60%'
                      : '${snap.grams.toStringAsFixed(0)} g · ngưỡng ${snap.forceMax}%',
                  status: snap == null ? 'Chờ mạch' : (snap.alarmForce ? 'Vượt ngưỡng' : 'Ổn'),
                  alarm: snap?.alarmForce ?? false,
                  color: const Color(0xFFFFC857),
                  icon: Icons.compress_rounded,
                  fraction: snap == null ? 0 : (snap.force / 100).clamp(0, 1),
                  samples: c.forceTrace,
                ),
                _SensorCard(
                  title: 'SpO2',
                  value: _spo2Value(snap),
                  unit: snap != null && snap.maxOnline && snap.finger && snap.spo2 > 0 ? '%' : '',
                  detail: _spo2Detail(snap),
                  status: _spo2Status(snap),
                  alarm: snap?.alarmSpo2 ?? false,
                  color: const Color(0xFF5CE1E6),
                  icon: Icons.bloodtype_rounded,
                  fraction: snap == null || snap.spo2 <= 0 ? 0 : (snap.spo2 / 100).clamp(0, 1),
                  samples: c.spo2Trace,
                ),
                _SensorCard(
                  title: 'Điện thế',
                  value: snap == null ? '--' : snap.piezo.toStringAsFixed(0),
                  unit: '%',
                  detail: snap == null
                      ? 'Ngưỡng 50%'
                      : '${snap.volt.toStringAsFixed(2)} V · ngưỡng ${snap.piezoMax}%',
                  status: snap == null ? 'Chờ mạch' : (snap.alarmPiezo ? 'Vượt ngưỡng' : 'Ổn'),
                  alarm: snap?.alarmPiezo ?? false,
                  color: const Color(0xFFC4B5FD),
                  icon: Icons.graphic_eq_rounded,
                  fraction: snap == null ? 0 : (snap.piezo / 100).clamp(0, 1),
                  samples: c.piezoTrace,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Ngưỡng trên mạch'),
            const SizedBox(height: 8),
            _thresholds(snap),
            const SizedBox(height: 16),
            const _SectionTitle('Màn OLED'),
            const SizedBox(height: 8),
            _oledCard(snap),
            const SizedBox(height: 16),
            const _SectionTitle('Kết nối mạch'),
            const SizedBox(height: 8),
            _connectCard(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AidSnapshot? snap) {
    final live = snap != null;
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AID', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text(
                'Thông số cảm biến',
                style: TextStyle(color: Color(0xFF8EAEA0), fontSize: 13),
              ),
            ],
          ),
        ),
        _pill(
          live ? 'Mạch ${snap.id}' : (c.connected ? 'MQTT' : 'Mất MQTT'),
          live || c.connected,
        ),
      ],
    );
  }

  Widget _alarmBanner(AidSnapshot snap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1418),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B7A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B7A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              snap.reason.isEmpty ? 'Cảnh báo ngưỡng' : snap.reason,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thresholds(AidSnapshot? snap) {
    final items = [
      ('Nhịp', snap == null ? '50–120' : '${snap.hrMin}–${snap.hrMax}'),
      ('Lực', snap == null ? '60%' : '${snap.forceMax}%'),
      ('SpO2', snap == null ? '< 92%' : '< ${snap.spo2Min}%'),
      ('Piezo', snap == null ? '50%' : '${snap.piezoMax}%'),
      ('Còi', snap == null ? '--' : (snap.buzzerOn ? (snap.mute ? 'Tắt tiếng' : 'Bật') : 'Tắt')),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF12201A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${item.$1}  ${item.$2}'),
          ),
      ],
    );
  }

  Widget _oledCard(AidSnapshot? snap) {
    final lines = snap == null
        ? const ['Chưa nhận dữ liệu từ mạch.', 'Mã chip hiện trên OLED lúc bật nguồn.']
        : [
            snap.title.isEmpty ? snap.screenName : snap.title,
            'Trạng thái ${snap.badge}',
            _hrDash(snap),
            _forceDash(snap),
            _spo2Dash(snap),
            _piezoDash(snap),
            if (snap.alarm) snap.reason,
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24352C)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFD6FF9A),
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line)],
        ),
      ),
    );
  }

  Widget _connectCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12201A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chip,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã mạch',
                    hintText: '6 ký tự trên OLED',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: c.setChip,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => c.setChip(_chip.text),
                child: const Text('Xem'),
              ),
            ],
          ),
          if (c.discovered.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final id in c.discovered)
                    ActionChip(
                      label: Text(id),
                      onPressed: () {
                        _chip.text = id;
                        c.setChip(id);
                      },
                    ),
                ],
              ),
            ),
          ],
          if (c.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(c.lastError, style: const TextStyle(color: Color(0xFFFF8A80))),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (final key in ['MENU', 'UP', 'DOWN', 'ENTER'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: c.connected ? () => c.sendButton(key) : null,
                      child: FittedBox(
                        child: Text(key == 'ENTER' ? 'ENT' : key, maxLines: 1, softWrap: false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.detail,
    required this.status,
    required this.alarm,
    required this.color,
    required this.icon,
    required this.fraction,
    required this.samples,
  });

  final String title;
  final String value;
  final String unit;
  final String detail;
  final String status;
  final bool alarm;
  final Color color;
  final IconData icon;
  final double fraction;
  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    final accent = alarm ? const Color(0xFFFF6B7A) : color;
    final waiting = value == '--';
    final statusColor = alarm ? const Color(0xFFFF6B7A) : (waiting ? const Color(0xFF8EAEA0) : color);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12201A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: alarm ? const Color(0xFFFF6B7A) : const Color(0xFF1E3329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: const TextStyle(color: Color(0xFFB7D0C4), fontSize: 13)),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: accent, height: 1)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(unit, style: const TextStyle(color: Color(0xFF8EAEA0), fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.toDouble(),
              minHeight: 4,
              backgroundColor: const Color(0xFF24352C),
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF8EAEA0))),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(painter: _Sparkline(samples, accent)),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.samples, this.color);
  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    var peak = 1.0;
    for (final v in samples) {
      if (v > peak) peak = v;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (samples.length - 1);
      final y = size.height - (samples[i].clamp(0, peak) / peak) * (size.height - 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _Sparkline oldDelegate) => true;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD7EBE1)));
  }
}

Widget _pill(String text, bool on) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF12201A),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: on ? const Color(0xFF3DDC97) : const Color(0xFFFF8A80)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

String _hrStatus(AidSnapshot? snap) {
  if (snap == null) return 'Chờ mạch';
  if (snap.alarmHr) return 'Ngoài ngưỡng';
  if (snap.hr > 0) return 'Ổn';
  return 'Chưa có nhịp';
}

String _spo2Value(AidSnapshot? snap) {
  if (snap == null || !snap.maxOnline) return '--';
  if (!snap.finger || snap.spo2 <= 0) return '--';
  return snap.spo2.toStringAsFixed(0);
}

String _spo2Detail(AidSnapshot? snap) {
  if (snap == null) return 'Ngưỡng dưới 92%';
  if (!snap.maxOnline) return 'Chưa thấy IC MAX3010x';
  if (!snap.finger) return 'Chưa đặt tay';
  return '${snap.spo2Hr.toStringAsFixed(0)} bpm · ngưỡng < ${snap.spo2Min}%';
}

String _spo2Status(AidSnapshot? snap) {
  if (snap == null) return 'Chờ mạch';
  if (!snap.maxOnline) return 'Không có IC';
  if (!snap.finger) return 'Chưa đặt tay';
  if (snap.alarmSpo2) return 'Thiếu oxy';
  return 'Ổn';
}

String _hrDash(AidSnapshot s) {
  if (s.hr > 0) return 'N.Tim: ${s.hr.toString().padLeft(3)} bpm${s.alarmHr ? ' !' : ''}';
  return 'N.Tim: --- bpm';
}

String _forceDash(AidSnapshot s) {
  final pct = s.force.toStringAsFixed(0).padLeft(3);
  final g = s.grams.toStringAsFixed(0).padLeft(4);
  return 'Luc  : $pct% (${g}g)${s.alarmForce ? ' !' : ''}';
}

String _spo2Dash(AidSnapshot s) {
  if (s.maxOnline && s.finger && s.spo2 > 0) {
    return 'SpO2 : ${s.spo2.toStringAsFixed(0).padLeft(3)}%${s.alarmSpo2 ? ' !' : ''}';
  }
  if (!s.maxOnline) return 'SpO2 : K.co IC';
  return 'SpO2 : Chua dat';
}

String _piezoDash(AidSnapshot s) {
  final pct = s.piezo.toStringAsFixed(0).padLeft(3);
  return 'Piezo: $pct% (${s.volt.toStringAsFixed(2)}V)${s.alarmPiezo ? ' !' : ''}';
}
