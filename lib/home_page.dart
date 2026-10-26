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
  int _view = 0;
  bool _follow = true;

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
    if (_chip.text != c.chipId && _chip.text.isEmpty) {
      _chip.text = c.chipId;
    }
    final snap = c.snapshot;
    if (_follow && snap != null && _view != snap.screen) {
      _view = snap.screen;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snap = c.snapshot;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18211C),
        title: const Text('AID'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _dot(c.connected, c.connected ? 'MQTT' : 'Mat MQTT')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const Text(
            'mqtt.duynguyen.io.vn',
            style: TextStyle(color: Color(0xFF8FB9A4)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chip,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Chip ID',
                    hintText: 'Vi du A1B2C3',
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          if (c.lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c.lastError, style: const TextStyle(color: Color(0xFFFF8A80))),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _dot(snap != null, snap == null ? 'Chua co du lieu' : 'Thiet bi online'),
              const SizedBox(width: 12),
              Text(snap == null ? 'Doi OLED...' : 'IP ${snap.ip}  ${snap.rssi} dBm'),
            ],
          ),
          if (snap != null && snap.alarm) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF8E1E1E),
              child: Text(
                snap.reason.isEmpty ? 'CANH BAO' : snap.reason,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Theo man OLED'),
              Switch(
                value: _follow,
                onChanged: (v) => setState(() {
                  _follow = v;
                  if (v && snap != null) _view = snap.screen;
                }),
              ),
            ],
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < oledScreenTitles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(oledScreenTitles[i].substring(3)),
                      selected: _view == i,
                      onSelected: (_) => setState(() {
                        _view = i;
                        _follow = false;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (snap == null)
            const _OledFrame(
              child: Center(
                child: Text(
                  'Chua nhan du lieu OLED.\nNhap chip ID tren man hinh ESP32.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            _OledFrame(child: _OledBody(snap: snap, view: _view, controller: c)),
          const SizedBox(height: 14),
          if (snap != null) _MetricGrid(snap: snap),
          const SizedBox(height: 14),
          const Text('Nut tren thiet bi'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final key in ['MENU', 'UP', 'DOWN', 'ENTER'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: c.connected ? () => c.sendButton(key) : null,
                      child: Text(key == 'ENTER' ? 'ENT' : key, style: const TextStyle(fontSize: 12)),
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

class _OledFrame extends StatelessWidget {
  const _OledFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF314238)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFD6FF9A),
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.15,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OledBody extends StatelessWidget {
  const _OledBody({
    required this.snap,
    required this.view,
    required this.controller,
  });

  final AidSnapshot snap;
  final int view;
  final AidController controller;

  @override
  Widget build(BuildContext context) {
    final title = view == snap.screen && snap.title.isNotEmpty
        ? snap.title
        : (view == 0 ? '1. ${snap.id}' : oledScreenTitles[view]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(view == snap.screen ? snap.badge : ''),
          ],
        ),
        const Divider(color: Color(0xFFD6FF9A), height: 8),
        Expanded(child: _screenBody()),
      ],
    );
  }

  Widget _screenBody() {
    switch (view) {
      case 1:
        return _graphScreen(
          big: snap.hr > 0 ? snap.hr.toString().padLeft(3) : '---',
          unit: 'BPM',
          extra: snap.hr > 0 ? '<3 BEAT' : '   BEAT',
          line: 'Nguong:${snap.hrMin}-${snap.hrMax}BPM  ${snap.alarmHr ? '[!]' : (snap.hr > 0 ? '[OK]' : '')}',
          samples: controller.hrTrace,
          tag: 'ECG',
        );
      case 2:
        return _graphScreen(
          big: '${snap.force.toStringAsFixed(0).padLeft(3)}%',
          unit: '~${snap.grams.toStringAsFixed(0)}g',
          extra: '',
          line: 'Nguong: >${snap.forceMax}%  ${snap.alarmForce ? '[ALARM!]' : '[OK]'}',
          samples: controller.forceTrace,
          tag: 'FSR',
          maxY: 100,
        );
      case 3:
        if (!snap.maxOnline) {
          return const Text('CHUA KET NOI IC (I2C1)\nKiem tra day SDA/SCL:\nPin 26 (SDA), 25 (SCL)');
        }
        final spo = snap.finger && snap.spo2 > 0 ? '${snap.spo2.toStringAsFixed(0)}%' : '--%';
        final bpm = snap.finger && snap.spo2Hr > 0 ? '${snap.spo2Hr.toStringAsFixed(0)}bpm' : '--bpm';
        return _graphScreen(
          big: spo,
          unit: 'SpO2  $bpm',
          extra: '',
          line: 'Nguong: <${snap.spo2Min}%  ${snap.alarmSpo2 ? '[ALARM!]' : (snap.finger ? '[OK]' : '')}',
          samples: snap.finger ? controller.spo2Trace : const [],
          tag: snap.finger ? 'PPG' : 'DAT TAY',
          maxY: 100,
        );
      case 4:
        return _graphScreen(
          big: '${snap.piezo.toStringAsFixed(0).padLeft(3)}%',
          unit: '${snap.volt.toStringAsFixed(2)}V',
          extra: '',
          line: 'Nguong: >${snap.piezoMax}%  ${snap.alarmPiezo ? '[ALARM!]' : '[OK]'}',
          samples: controller.piezoTrace,
          tag: 'VIB',
          maxY: 100,
        );
      case 5:
        return _settings();
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_hrDash(snap)),
            Text(_forceDash(snap)),
            Text(_spo2Dash(snap)),
            Text(_piezoDash(snap)),
            if (snap.alarm)
              Text(snap.reason, style: const TextStyle(color: Colors.black, backgroundColor: Color(0xFFD6FF9A))),
          ],
        );
    }
  }

  Widget _graphScreen({
    required String big,
    required String unit,
    required String extra,
    required String line,
    required List<double> samples,
    required String tag,
    double maxY = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$big  $unit  $extra', style: const TextStyle(fontSize: 16)),
        Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Expanded(
          child: ClipRect(
            child: CustomPaint(
              painter: _TracePainter(
                samples: samples,
                oledWave: view == snap.screen ? snap.wave : const [],
                maxY: maxY,
                tag: tag,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settings() {
    const labels = [
      '1.Luc Max (%)',
      '2.Nhip tim Min',
      '3.Nhip tim Max',
      '4.SpO2 Min (%)',
      '5.Piezo Max(%)',
      '6.Coi bao (BZ)',
    ];
    final values = [
      '${snap.forceMax}%',
      '${snap.hrMin}',
      '${snap.hrMax}',
      '${snap.spo2Min}%',
      '${snap.piezoMax}%',
      snap.buzzerOn ? 'BAT' : 'TAT',
    ];
    var start = 0;
    if (snap.cursor >= 3) {
      start = snap.cursor - 2;
      if (start > 2) start = 2;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++)
          Text(
            '${start + i == snap.cursor ? (snap.editing ? '*' : '>') : ' '} ${labels[start + i]}: ${values[start + i]}',
          ),
        Text(snap.editing ? 'UP/DOWN:Doi | ENT:Luu' : 'UP/DN:Chon | ENT:Sua'),
      ],
    );
  }
}

String _hrDash(AidSnapshot s) {
  if (s.hr > 0) {
    return 'N.Tim: ${s.hr.toString().padLeft(3)} bpm${s.alarmHr ? ' !' : ''}';
  }
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

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.samples,
    required this.oledWave,
    required this.maxY,
    required this.tag,
  });

  final List<double> samples;
  final List<int> oledWave;
  final double maxY;
  final String tag;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = const Color(0xFFD6FF9A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, frame);
    final paint = Paint()
      ..color = const Color(0xFFD6FF9A)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    if (oledWave.length >= 2) {
      final path = Path();
      for (var i = 0; i < oledWave.length; i++) {
        final x = size.width * i / (oledWave.length - 1);
        final yNorm = ((oledWave[i] - 36) / 26).clamp(0.0, 1.0);
        final y = yNorm * (size.height - 4) + 2;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    } else if (samples.length >= 2) {
      final path = Path();
      final peak = maxY > 0 ? maxY : samples.reduce((a, b) => a > b ? a : b).clamp(1, 10000);
      for (var i = 0; i < samples.length; i++) {
        final x = size.width * i / (samples.length - 1);
        final y = size.height - 2 - (samples[i].clamp(0, peak) / peak) * (size.height - 6);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    final tp = TextPainter(
      text: TextSpan(text: tag, style: const TextStyle(color: Color(0xFFD6FF9A), fontSize: 10, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 4, 2));
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) => true;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snap});
  final AidSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Nhip tim', snap.hr > 0 ? '${snap.hr} bpm' : '---', 'ADC ${snap.hrAdc}'),
      ('Luc', '${snap.force.toStringAsFixed(0)}%', '${snap.grams.toStringAsFixed(0)} g'),
      ('SpO2', snap.maxOnline ? (snap.finger ? '${snap.spo2.toStringAsFixed(0)}%' : 'Chua dat tay') : 'Khong co IC', '${snap.spo2Hr.toStringAsFixed(0)} bpm'),
      ('Piezo', '${snap.piezo.toStringAsFixed(0)}%', '${snap.volt.toStringAsFixed(2)} V'),
      ('Coi', snap.buzzerOn ? (snap.mute ? 'MUTE' : 'BAT') : 'TAT', snap.badge),
      ('Nguong', 'HR ${snap.hrMin}-${snap.hrMax}', 'SpO2 < ${snap.spo2Min}%'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF18211C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1, style: const TextStyle(color: Color(0xFF8FB9A4), fontSize: 12)),
                Text(item.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(item.$3, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _dot(bool on, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: on ? const Color(0xFF3DDC97) : const Color(0xFFFF8A80)),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}
