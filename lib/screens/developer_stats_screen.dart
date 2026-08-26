import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Developer dashboard showing overview statistics.
class DeveloperStatsScreen extends StatefulWidget {
  const DeveloperStatsScreen({super.key});

  @override
  State<DeveloperStatsScreen> createState() => _DeveloperStatsScreenState();
}

class _DeveloperStatsScreenState extends State<DeveloperStatsScreen> {
  final _supabase = Supabase.instance.client;

  int _totalDrivers = 0;
  int _totalTrips = 0;
  int _totalFeedback = 0;
  double _totalDistance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      // จำนวนคนขับทั้งหมด
      final drivers = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'driver');

      // จำนวนเที่ยวทั้งหมด
      final trips = await _supabase
          .from('trip_logs')
          .select('id, distance');

      // จำนวน feedback ทั้งหมด
      final feedback = await _supabase
          .from('feedback')
          .select('id');

      // ระยะทางรวม
      double totalDistance = 0;
      for (final trip in trips) {
        final d = trip['distance'];
        if (d is num) totalDistance += d.toDouble();
      }

      if (mounted) {
        setState(() {
          _totalDrivers = drivers.length;
          _totalTrips = trips.length;
          _totalFeedback = feedback.length;
          _totalDistance = totalDistance;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              const Text(
                'ภาพรวมระบบ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'สถิติทั้งหมดของ driverLog',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const _StatsSkeleton()
              else ...[
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_rounded,
                        label: 'คนขับทั้งหมด',
                        value: '$_totalDrivers',
                        unit: 'คน',
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.route_rounded,
                        label: 'เที่ยวทั้งหมด',
                        value: '$_totalTrips',
                        unit: 'เที่ยว',
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed_rounded,
                        label: 'ระยะทางรวม',
                        value: _totalDistance.toStringAsFixed(0),
                        unit: 'กม.',
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.feedback_rounded,
                        label: 'Feedback',
                        value: '$_totalFeedback',
                        unit: 'รายการ',
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick actions
                const Text(
                  'ลัด',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _QuickAction(
                  icon: Icons.storage_rounded,
                  title: 'Supabase Dashboard',
                  subtitle: 'จัดการ database โดยตรง',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _QuickAction(
                  icon: Icons.cloud_rounded,
                  title: 'Cloudflare Dashboard',
                  subtitle: 'จัดการ hosting และ deploy',
                  onTap: () {},
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(
            2,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 0 ? 12 : 0),
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(
            2,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 0 ? 12 : 0),
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
