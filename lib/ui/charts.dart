import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/device_snapshot.dart';
import 'theme.dart';

class AidCharts extends StatelessWidget {
  const AidCharts({
    super.key,
    required this.history,
    required this.pulseMin,
    required this.pulseMax,
    required this.spo2Min,
    required this.forceThresh,
    required this.piezoThresh,
  });

  final List<SamplePoint> history;
  final int pulseMin;
  final int pulseMax;
  final int spo2Min;
  final int forceThresh;
  final int piezoThresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diễn biến trên máy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(
          'Số liệu lấy mỗi lần app hỏi ESP32',
          style: TextStyle(
            color: AidTheme.soft.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _chart(
          'Nhịp tim',
          history,
          (p) => p.pulseBpm,
          AidTheme.pulse,
          ' BPM',
          minLine: pulseMin.toDouble(),
          maxLine: pulseMax.toDouble(),
        ),
        const SizedBox(height: 14),
        _chart(
          'SpO2',
          history,
          (p) => p.spo2,
          AidTheme.spo2,
          '%',
          minLine: spo2Min.toDouble(),
        ),
        const SizedBox(height: 14),
        _chart(
          'Lực ép',
          history,
          (p) => p.forcePct,
          AidTheme.force,
          '%',
          maxLine: forceThresh.toDouble(),
        ),
        const SizedBox(height: 14),
        _chart(
          'Rung / xung',
          history,
          (p) => p.piezoPct,
          AidTheme.piezo,
          '%',
          maxLine: piezoThresh.toDouble(),
        ),
      ],
    );
  }

  Widget _chart(
    String title,
    List<SamplePoint> points,
    double Function(SamplePoint) pick,
    Color color,
    String unit, {
    double? minLine,
    double? maxLine,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          height: 168,
          padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
          decoration: BoxDecoration(
            color: AidTheme.panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: points.isEmpty
              ? const Center(
                  child: Text(
                    'Đang ghi nhận...',
                    style: TextStyle(color: AidTheme.muted),
                  ),
                )
              : _Line(
                  points: points,
                  pick: pick,
                  color: color,
                  unit: unit,
                  minLine: minLine,
                  maxLine: maxLine,
                ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.points,
    required this.pick,
    required this.color,
    required this.unit,
    this.minLine,
    this.maxLine,
  });

  final List<SamplePoint> points;
  final double Function(SamplePoint) pick;
  final Color color;
  final String unit;
  final double? minLine;
  final double? maxLine;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), pick(points[i])),
    ];
    var minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (minLine != null && minLine! < minY) minY = minLine!;
    if (maxLine != null && maxLine! > maxY) maxY = maxLine!;
    if (maxY - minY < 4) {
      minY -= 2;
      maxY += 2;
    } else {
      minY -= 1;
      maxY += 1;
    }
    if (minY < 0) minY = 0;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, _) => Text(
                '${value.toStringAsFixed(0)}$unit',
                style: TextStyle(
                  fontSize: 10,
                  color: AidTheme.soft.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (minLine != null)
              HorizontalLine(
                y: minLine!,
                color: AidTheme.safe.withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [5, 4],
              ),
            if (maxLine != null)
              HorizontalLine(
                y: maxLine!,
                color: AidTheme.pulse.withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [5, 4],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}
