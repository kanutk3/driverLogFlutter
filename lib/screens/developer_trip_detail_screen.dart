import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Developer screen showing full detail of a single trip.
class DeveloperTripDetailScreen extends StatelessWidget {
  const DeveloperTripDetailScreen({super.key, required this.trip});
  final Map<String, dynamic> trip;

  String _fmt(String? iso, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return iso;
    }
  }

  Duration? get _duration {
    final start = trip['start_time'];
    final end = trip['end_time'];
    if (start == null || end == null) return null;
    try {
      final s = DateTime.parse(start).toLocal();
      final e = DateTime.parse(end).toLocal();
      return e.difference(s);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h ชม. $m น.';
    return '$m นาที';
  }

  @override
  Widget build(BuildContext context) {
    final profile = trip['profiles'] as Map<String, dynamic>?;
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final distance = trip['distance'];
    final duration = _duration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดเที่ยว'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          _DetailCard(
            children: [
              _DetailRow(
                icon: Icons.flag_rounded,
                label: 'จุดหมาย',
                value: trip['destination'] ?? '-',
                valueStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Icons.person_rounded,
                label: 'คนขับ',
                value: profile?['display_name'] ??
                    profile?['google_name'] ??
                    '-',
              ),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'อีเมล',
                value: profile?['email'] ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vehicle card
          _DetailCard(
            title: '🚗 ข้อมูลรถ',
            children: [
              _DetailRow(
                icon: Icons.pin_rounded,
                label: 'ทะเบียน',
                value: vehicle?['vehicle_plate'] ?? '-',
              ),
              _DetailRow(
                icon: Icons.directions_car_rounded,
                label: 'ยี่ห้อ',
                value: vehicle?['vehicle_brand'] ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Time card
          _DetailCard(
            title: '⏱️ เวลา',
            children: [
              _DetailRow(
                icon: Icons.play_circle_outline,
                label: 'เริ่ม',
                value: _fmt(trip['start_time']),
              ),
              _DetailRow(
                icon: Icons.stop_circle_outlined,
                label: 'สิ้นสุด',
                value: _fmt(trip['end_time']),
              ),
              if (duration != null)
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: 'ระยะเวลา',
                  value: _formatDuration(duration),
                  valueStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats card
          _DetailCard(
            title: '📊 สถิติ',
            children: [
              if (distance is num)
                _DetailRow(
                  icon: Icons.speed_rounded,
                  label: 'ระยะทาง',
                  value: '${distance.toDouble().toStringAsFixed(1)} กม.',
                  valueStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
              if (distance is num && duration != null && duration.inMinutes > 0)
                _DetailRow(
                  icon: Icons.show_chart_rounded,
                  label: 'ความเร็วเฉลี่ย',
                  value:
                      '${(distance.toDouble() / (duration.inMinutes / 60)).toStringAsFixed(1)} กม./ชม.',
                ),
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Trip ID',
                value: trip['id'] ?? '-',
                valueStyle: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: valueStyle ??
                  const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
