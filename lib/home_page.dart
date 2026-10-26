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
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _header(snap),
            const SizedBox(height: 14),
            if (snap != null && snap.alarm) ...[
              _alarmBanner(snap),
              const SizedBox(height: 12),
            ],
            const _SectionTitle('Biểu đồ cảm biến'),
            const SizedBox(height: 8),
            _ChartCard(
              title: 'Nhịp tim',
              caption: 'Pulse · GPIO 33',
              value: snap == null || snap.hr <= 0 ? '--' : '${snap.hr}',
              unit: 'bpm',
              detail: snap == null
                  ? 'Ngưỡng an toàn 50–120 bpm'
                  : 'ADC ${snap.hrAdc} · ngưỡng ${snap.hrMin}–${snap.hrMax} bpm',
              status: _hrStatus(snap),
              alarm: snap?.alarmHr ?? false,
              color: const Color(0xFFE11D48),
              icon: Icons.favorite_rounded,
              samples: c.hrTrace,
              minY: 40,
              maxY: 180,
              low: snap?.hrMin.toDouble() ?? 50,
              high: snap?.hrMax.toDouble() ?? 120,
            ),
            _ChartCard(
              title: 'Lực',
              caption: 'Force FSR · GPIO 32',
              value: snap == null ? '--' : snap.force.toStringAsFixed(0),
              unit: '%',
              detail: snap == null
                  ? 'Ngưỡng 60%'
                  : '${snap.grams.toStringAsFixed(0)} g · ngưỡng ${snap.forceMax}%',
              status: snap == null ? 'Chờ mạch' : (snap.alarmForce ? 'Vượt ngưỡng' : 'Ổn'),
              alarm: snap?.alarmForce ?? false,
              color: const Color(0xFFD97706),
              icon: Icons.compress_rounded,
              samples: c.forceTrace,
              minY: 0,
              maxY: 100,
              high: snap?.forceMax.toDouble() ?? 60,
            ),
            _ChartCard(
              title: 'SpO2',
              caption: 'MAX3010x · GPIO 26/25',
              value: _spo2Value(snap),
              unit: '%',
              detail: _spo2Detail(snap),
              status: _spo2Status(snap),
              alarm: snap?.alarmSpo2 ?? false,
              color: const Color(0xFF0891B2),
              icon: Icons.bloodtype_rounded,
              samples: c.spo2Trace,
              minY: 70,
              maxY: 100,
              low: snap?.spo2Min.toDouble() ?? 92,
            ),
            _ChartCard(
              title: 'Điện thế',
              caption: 'Piezo · GPIO 35',
              value: snap == null ? '--' : snap.piezo.toStringAsFixed(0),
              unit: '%',
              detail: snap == null
                  ? 'Ngưỡng 50%'
                  : '${snap.volt.toStringAsFixed(2)} V · ngưỡng ${snap.piezoMax}%',
              status: snap == null ? 'Chờ mạch' : (snap.alarmPiezo ? 'Vượt ngưỡng' : 'Ổn'),
              alarm: snap?.alarmPiezo ?? false,
              color: const Color(0xFF7C3AED),
              icon: Icons.graphic_eq_rounded,
              samples: c.piezoTrace,
              minY: 0,
              maxY: 100,
              high: snap?.piezoMax.toDouble() ?? 50,
            ),
            const SizedBox(height: 4),
            const _SectionTitle('Ngưỡng cảnh báo'),
            const SizedBox(height: 8),
            _thresholds(snap),
            const SizedBox(height: 16),
            const _SectionTitle('Màn OLED trên mạch'),
            const SizedBox(height: 8),
            _oledCard(snap),
            const SizedBox(height: 16),
            const _SectionTitle('Kết nối MQTT'),
            const SizedBox(height: 8),
            _connectCard(),
          ],
        ),
      ),
    );
  }

  Widget _header(AidSnapshot? snap) {
    final live = snap != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D4C), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SMART FIRST AID',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          const Text(
            'Đồ án STEM · Thiết bị sơ cứu thông minh',
            style: TextStyle(color: Color(0xFFD7F3EF), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(c.connected ? 'MQTT đã nối' : 'Mất MQTT', c.connected),
              _pill(live ? 'Mạch ${snap.id}' : 'Chờ mạch', live),
              if (live) _pill(snap.wifi ? snap.ip : 'Mất WiFi', snap.wifi),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alarmBanner(AidSnapshot snap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFB7185)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              snap.reason.isEmpty ? 'Cảnh báo ngưỡng' : snap.reason,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thresholds(AidSnapshot? snap) {
    final items = [
      ('Nhịp', snap == null ? '50–120 bpm' : '${snap.hrMin}–${snap.hrMax} bpm'),
      ('Lực', snap == null ? '60%' : '${snap.forceMax}%'),
      ('SpO2', snap == null ? 'trên 92%' : 'trên ${snap.spo2Min}%'),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text('${item.$1}  ${item.$2}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
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
        color: const Color(0xFF07110E),
        borderRadius: BorderRadius.circular(16),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'mqtt.duynguyen.io.vn',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chip,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Color(0xFF0F172A)),
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
            Wrap(
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
          ],
          if (c.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c.lastError, style: const TextStyle(color: Color(0xFFE11D48))),
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
                        foregroundColor: const Color(0xFF0F3D4C),
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.caption,
    required this.value,
    required this.unit,
    required this.detail,
    required this.status,
    required this.alarm,
    required this.color,
    required this.icon,
    required this.samples,
    required this.minY,
    required this.maxY,
    this.low,
    this.high,
  });

  final String title;
  final String caption;
  final String value;
  final String unit;
  final String detail;
  final String status;
  final bool alarm;
  final Color color;
  final IconData icon;
  final List<double> samples;
  final double minY;
  final double maxY;
  final double? low;
  final double? high;

  @override
  Widget build(BuildContext context) {
    final waiting = value == '--';
    final statusColor = alarm
        ? const Color(0xFFE11D48)
        : (waiting ? const Color(0xFF64748B) : const Color(0xFF0F766E));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: alarm ? const Color(0xFFFB7185) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(caption, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: color, height: 1),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: const TextStyle(fontSize: 16, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            width: double.infinity,
            child: CustomPaint(
              painter: _StemChart(
                samples: samples,
                color: color,
                minY: minY,
                maxY: maxY,
                low: low,
                high: high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StemChart extends CustomPainter {
  _StemChart({
    required this.samples,
    required this.color,
    required this.minY,
    required this.maxY,
    this.low,
    this.high,
  });

  final List<double> samples;
  final Color color;
  final double minY;
  final double maxY;
  final double? low;
  final double? high;

  @override
  void paint(Canvas canvas, Size size) {
    const axisW = 32.0;
    final plot = Rect.fromLTWH(axisW, 4, size.width - axisW - 4, size.height - 8);
    final bg = RRect.fromRectAndRadius(plot, const Radius.circular(10));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawRRect(
      bg,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke,
    );

    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    _axisLabel(canvas, maxY.toStringAsFixed(0), plot.top, axisW);
    _axisLabel(canvas, minY.toStringAsFixed(0), plot.bottom - 12, axisW);

    void guide(double? value) {
      if (value == null) return;
      final y = _y(value, plot);
      final paint = Paint()
        ..color = const Color(0xFFF43F5E)
        ..strokeWidth = 1;
      for (double x = plot.left; x < plot.right; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
      }
    }

    guide(low);
    guide(high);

    if (samples.isEmpty) {
      _centerNote(canvas, plot, 'Chưa có mẫu');
      return;
    }

    final points = samples.length == 1 ? [samples.first, samples.first] : samples;
    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = plot.left + plot.width * i / (points.length - 1);
      final y = _y(points[i], plot);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, plot.bottom);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(plot.right, plot.bottom);
    fill.close();
    canvas.save();
    canvas.clipRRect(bg);
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  double _y(double value, Rect plot) {
    final span = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);
    final t = ((value - minY) / span).clamp(0.0, 1.0);
    return plot.bottom - t * plot.height;
  }

  void _axisLabel(Canvas canvas, String text, double top, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(0, top));
  }

  void _centerNote(Canvas canvas, Rect plot, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(plot.center.dx - painter.width / 2, plot.center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _StemChart oldDelegate) => true;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
    );
  }
}

Widget _pill(String text, bool on) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: on ? const Color(0xFF86EFAC) : const Color(0xFFFDA4AF)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
  if (snap == null) return 'Ngưỡng trên 92%';
  if (!snap.maxOnline) return 'Chưa thấy IC MAX3010x';
  if (!snap.finger) return 'Chưa đặt tay lên cảm biến';
  return '${snap.spo2Hr.toStringAsFixed(0)} bpm · ngưỡng trên ${snap.spo2Min}%';
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
