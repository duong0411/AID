import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/device_api.dart';
import '../core/monitor_provider.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _force;
  late int _pulseMin;
  late int _pulseMax;
  late int _spo2Min;
  late int _piezo;
  late bool _buzzer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<MonitorProvider>().data;
    _force = data?.forceThresh ?? 60;
    _pulseMin = data?.pulseMin ?? 50;
    _pulseMax = data?.pulseMax ?? 120;
    _spo2Min = data?.spo2Min ?? 92;
    _piezo = data?.piezoThresh ?? 50;
    _buzzer = data?.buzzerEnabled ?? true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<MonitorProvider>().saveSettings(
            forceThresh: _force,
            pulseMin: _pulseMin,
            pulseMax: _pulseMax,
            spo2Min: _spo2Min,
            piezoThresh: _piezo,
            buzzerEnabled: _buzzer,
          );
      if (!mounted) return;
      showAppSnack(context, message: 'Đã lưu ngưỡng vào mạch', success: true);
      Navigator.of(context).pop();
    } on DeviceException catch (e) {
      if (!mounted) return;
      showAppSnack(context, message: e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AidTheme.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AidTheme.soft,
        title: const Text('Ngưỡng cảnh báo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _step(
            'Lực tối đa',
            '$_force%',
            () => setState(() => _force = (_force - 5).clamp(10, 100)),
            () => setState(() => _force = (_force + 5).clamp(10, 100)),
          ),
          _step(
            'Nhịp tim tối thiểu',
            '$_pulseMin BPM',
            () => setState(() {
              _pulseMin = (_pulseMin - 5).clamp(30, _pulseMax - 5);
            }),
            () => setState(() {
              _pulseMin = (_pulseMin + 5).clamp(30, _pulseMax - 5);
            }),
          ),
          _step(
            'Nhịp tim tối đa',
            '$_pulseMax BPM',
            () => setState(() {
              _pulseMax = (_pulseMax - 5).clamp(_pulseMin + 5, 220);
            }),
            () => setState(() {
              _pulseMax = (_pulseMax + 5).clamp(_pulseMin + 5, 220);
            }),
          ),
          _step(
            'SpO2 tối thiểu',
            '$_spo2Min%',
            () => setState(() => _spo2Min = (_spo2Min - 1).clamp(75, 99)),
            () => setState(() => _spo2Min = (_spo2Min + 1).clamp(75, 99)),
          ),
          _step(
            'Rung tối đa',
            '$_piezo%',
            () => setState(() => _piezo = (_piezo - 5).clamp(10, 100)),
            () => setState(() => _piezo = (_piezo + 5).clamp(10, 100)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cho phép còi báo'),
            subtitle: const Text('Lưu vào bộ nhớ của ESP32'),
            value: _buzzer,
            onChanged: (value) => setState(() => _buzzer = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AidTheme.spo2,
              foregroundColor: AidTheme.deep,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _saving ? 'Đang lưu...' : 'Lưu xuống mạch',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String label, String value, VoidCallback down, VoidCallback up) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AidTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AidTheme.muted, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
          IconButton(onPressed: down, icon: const Icon(Icons.remove_rounded)),
          IconButton(onPressed: up, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}
