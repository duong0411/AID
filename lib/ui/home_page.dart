import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/device_api.dart';
import '../core/monitor_provider.dart';
import '../core/practice_session.dart';
import 'charts.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets/feedback.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<MonitorProvider>();
    final data = device.data;
    if (data == null) return const SizedBox.shrink();

    final spo2Text = !data.maxOnline
        ? 'Ngoại tuyến'
        : (!data.finger ? 'Chưa có tay' : '${data.spo2.toStringAsFixed(0)}%');
    final pulseText = data.pulseBpm <= 0 ? '--' : '${data.pulseBpm}';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070B12), AidTheme.deep, Color(0xFF171022)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AidTheme.spo2,
            onRefresh: device.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SMART FIRST AID',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: device.live ? AidTheme.safe : AidTheme.force,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  device.live
                                      ? (device.isMqtt
                                          ? 'Từ xa · chip ${device.chipId}'
                                          : 'Gần máy · ${device.host}')
                                      : device.status,
                                  style: const TextStyle(color: AidTheme.muted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ngưỡng cảnh báo',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded, color: AidTheme.soft),
                    ),
                    IconButton(
                      tooltip: 'Ngắt kết nối',
                      onPressed: () => context.read<MonitorProvider>().disconnect(),
                      icon: const Icon(Icons.link_off_rounded, color: AidTheme.soft),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AlarmBanner(device: device),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Nhịp tim',
                        value: pulseText,
                        unit: data.pulseBpm <= 0 ? '' : 'BPM',
                        detail: 'ADC ${data.pulseRaw}',
                        icon: Icons.favorite_rounded,
                        color: AidTheme.pulse,
                        alert: data.alarmPulse,
                        beat: data.beat,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Oxy máu',
                        value: spo2Text,
                        unit: '',
                        detail: data.maxOnline
                            ? 'Nhịp SpO2 ${data.spo2Bpm.toStringAsFixed(0)}'
                            : 'Chưa thấy MAX3010x',
                        icon: Icons.air_rounded,
                        color: AidTheme.spo2,
                        alert: data.alarmSpo2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Lực ép',
                        value: data.forcePct.toStringAsFixed(0),
                        unit: '%',
                        detail: '${data.forceGrams.toStringAsFixed(0)} g',
                        icon: Icons.compress_rounded,
                        color: AidTheme.force,
                        alert: data.alarmForce,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Rung / xung',
                        value: data.piezoPct.toStringAsFixed(0),
                        unit: '%',
                        detail: '${data.piezoVolts.toStringAsFixed(2)} V',
                        icon: Icons.graphic_eq_rounded,
                        color: AidTheme.piezo,
                        alert: data.alarmPiezo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: data.buzzerMuted ? 'Bật lại còi' : 'Tắt tiếng còi',
                        icon: data.buzzerMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: data.buzzerMuted ? AidTheme.force : AidTheme.soft,
                        onTap: () => _act(context, device.toggleMute),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: 'Thử còi',
                        icon: Icons.notifications_active_rounded,
                        color: AidTheme.pulse,
                        onTap: () => _act(context, device.testAlarm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Còi ${data.buzzerEnabled ? 'đang cho phép' : 'đang tắt trong cài đặt'}'
                  ' · máy chạy ${_uptime(data.uptime)}',
                  style: const TextStyle(color: AidTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _PracticePanel(device: device),
                const SizedBox(height: 22),
                AidCharts(
                  history: device.history,
                  pulseMin: data.pulseMin,
                  pulseMax: data.pulseMax,
                  spo2Min: data.spo2Min,
                  forceThresh: data.forceThresh,
                  piezoThresh: data.piezoThresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, Future<void> Function() run) async {
    try {
      await run();
    } on DeviceException catch (e) {
      if (context.mounted) showAppSnack(context, message: e.message);
    }
  }

  String _uptime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}g ${m}p';
    return '${m}p ${s}s';
  }
}

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({required this.device});
  final MonitorProvider device;

  @override
  Widget build(BuildContext context) {
    final running = device.practiceRunning;
    final sessions = device.practiceSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Thực hành đo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
            if (sessions.isNotEmpty && !running)
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AidTheme.panel,
                      title: const Text('Xóa lịch sử?'),
                      content: const Text('Xóa toàn bộ các lần thực hành đã lưu trên máy này.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Xóa', style: TextStyle(color: AidTheme.pulse)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await context.read<MonitorProvider>().clearPracticeHistory();
                    if (context.mounted) {
                      showAppSnack(context, message: 'Đã xóa lịch sử thực hành');
                    }
                  }
                },
                child: const Text('Xóa hết', style: TextStyle(color: AidTheme.muted)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          running
              ? 'Đang ghi lần đo — bấm Kết thúc để lưu vào danh sách.'
              : 'Bấm Bắt đầu khi thực hành đo trên máy, rồi Kết thúc để lưu.',
          style: const TextStyle(color: AidTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Material(
          color: running
              ? AidTheme.pulse.withValues(alpha: 0.16)
              : AidTheme.panel,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (running) {
                final session = await context.read<MonitorProvider>().stopPractice();
                if (context.mounted && session != null) {
                  showAppSnack(
                    context,
                    message:
                        'Đã lưu lần đo ${session.durationLabel} · TB ${session.avgPulse.toStringAsFixed(0)} BPM',
                    success: true,
                  );
                }
              } else {
                context.read<MonitorProvider>().startPractice();
                showAppSnack(context, message: 'Đã bắt đầu ghi lần thực hành', success: true);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    running ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded,
                    color: running ? AidTheme.pulse : AidTheme.safe,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      running ? 'Kết thúc & lưu lần đo' : 'Bắt đầu lần thực hành đo',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (running)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AidTheme.pulse.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ĐANG GHI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AidTheme.pulse,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          sessions.isEmpty
              ? 'Chưa có lần thực hành nào được lưu.'
              : 'Các lần đã lưu (${sessions.length})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AidTheme.panel.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Text(
              'Sau mỗi lần đo, kết quả (nhịp TB, SpO2, lực max, số cảnh báo) sẽ hiện ở đây.',
              style: TextStyle(color: AidTheme.muted, fontSize: 12, height: 1.4),
            ),
          )
        else
          ...sessions.take(12).map((s) => _PracticeTile(session: s)),
      ],
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({required this.session});
  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AidTheme.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                session.timeLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                session.durationLabel,
                style: const TextStyle(color: AidTheme.muted, fontSize: 12),
              ),
              const Spacer(),
              if (session.alarmCount > 0)
                Text(
                  '${session.alarmCount} cảnh báo',
                  style: const TextStyle(color: AidTheme.pulse, fontSize: 12, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            session.modeLabel,
            style: const TextStyle(color: AidTheme.muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _chip('Nhịp TB', session.avgPulse <= 0 ? '--' : '${session.avgPulse.toStringAsFixed(0)} BPM', AidTheme.pulse),
              _chip('Nhịp max', session.maxPulse <= 0 ? '--' : '${session.maxPulse.toStringAsFixed(0)}', AidTheme.pulse),
              _chip('SpO2 TB', session.avgSpo2 <= 0 ? '--' : '${session.avgSpo2.toStringAsFixed(0)}%', AidTheme.spo2),
              _chip('SpO2 min', session.minSpo2 <= 0 ? '--' : '${session.minSpo2.toStringAsFixed(0)}%', AidTheme.spo2),
              _chip('Lực max', '${session.maxForce.toStringAsFixed(0)}%', AidTheme.force),
              _chip('Rung max', '${session.maxPiezo.toStringAsFixed(0)}%', AidTheme.piezo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _AlarmBanner extends StatelessWidget {
  const _AlarmBanner({required this.device});
  final MonitorProvider device;

  @override
  Widget build(BuildContext context) {
    final data = device.data!;
    final danger = data.alarmActive;
    final color = danger ? AidTheme.pulse : AidTheme.safe;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            danger ? Icons.warning_rounded : Icons.verified_user_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              danger
                  ? data.alarmLabel
                  : 'Các chỉ số đang trong ngưỡng cho phép',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.detail,
    required this.icon,
    required this.color,
    required this.alert,
    this.beat = false,
  });

  final String label;
  final String value;
  final String unit;
  final String detail;
  final IconData icon;
  final Color color;
  final bool alert;
  final bool beat;

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AidTheme.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alert ? color.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AidTheme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              beat
                  ? iconBox.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 500.ms,
                      )
                  : iconBox,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 6 ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: alert ? color : AidTheme.soft,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: const TextStyle(color: AidTheme.muted)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: AidTheme.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AidTheme.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
