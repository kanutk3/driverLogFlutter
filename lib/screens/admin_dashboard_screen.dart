import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin dashboard showing system overview with detailed stats.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;

  int _totalDrivers = 0;
  int _totalDevelopers = 0;
  int _totalAdmins = 0;
  int _totalTrips = 0;
  int _totalFeedback = 0;
  int _totalVehicles = 0;
  double _totalDistance = 0;
  List<Map<String, dynamic>> _recentTrips = [];
  List<Map<String, dynamic>> _recentFeedback = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      // นับ role แต่ละประเภท
      final drivers = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'driver');

      final developers = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'developer');

      final admins = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      // จำนวนเที่ยว + ระยะทางรวม
      final trips = await _supabase
          .from('trip_logs')
          .select('id, distance');

      // จำนวน feedback
      final feedback = await _supabase
          .from('feedback')
          .select('id');

      // จำนวนรถ
      final vehicles = await _supabase
          .from('vehicles')
          .select('id');

      // เที่ยวล่าสุด 5 เที่ยว
      final recentTrips = await _supabase
          .from('trip_logs')
          .select('''
            id, destination, start_time, distance,
            profiles(display_name),
            vehicles(vehicle_plate)
          ''')
          .order('start_time', ascending: false)
          .limit(5);

      // feedback ล่าสุด 5 รายการ
      final recentFeedback = await _supabase
          .from('feedback')
          .select('*, profiles(display_name)')
          .order('created_at', ascending: false)
          .limit(5);

      // คำนวณระยะทางรวม
      double totalDistance = 0;
      for (final trip in trips) {
        final d = trip['distance'];
        if (d is num) totalDistance += d.toDouble();
      }

      if (mounted) {
        setState(() {
          _totalDrivers = drivers.length;
          _totalDevelopers = developers.length;
          _totalAdmins = admins.length;
          _totalTrips = trips.length;
          _totalFeedback = feedback.length;
          _totalVehicles = vehicles.length;
          _totalDistance = totalDistance;
          _recentTrips = List<Map<String, dynamic>>.from(recentTrips);
          _recentFeedback = List<Map<String, dynamic>>.from(recentFeedback);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      return iso;
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
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ภาพรวมระบบ driverLog',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const _StatsSkeleton()
              else ...[
                // Role breakdown
                _SectionTitle(title: 'ผู้ใช้ทั้งหมด'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.people_rounded,
                        label: 'คนขับ',
                        value: '$_totalDrivers',
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.code_rounded,
                        label: 'Developer',
                        value: '$_totalDevelopers',
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Admin',
                        value: '$_totalAdmins',
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // System stats
                _SectionTitle(title: 'สถิติระบบ'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.route_rounded,
                        label: 'เที่ยวทั้งหมด',
                        value: '$_totalTrips',
                        unit: 'เที่ยว',
                        color: const Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed_rounded,
                        label: 'ระยะทางรวม',
                        value: _totalDistance.toStringAsFixed(0),
                        unit: 'กม.',
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.directions_car_rounded,
                        label: 'รถทั้งหมด',
                        value: '$_totalVehicles',
                        unit: 'คัน',
                        color: const Color(0xFF0891B2),
                      ),
                    ),
                    const SizedBox(width: 10),
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

                // Recent trips
                _SectionTitle(title: 'เที่ยวล่าสุด'),
                const SizedBox(height: 10),
                if (_recentTrips.isEmpty)
                  const _EmptyState(text: 'ยังไม่มีเที่ยว')
                else
                  ..._recentTrips.map((trip) => _RecentTripTile(
                        trip: trip,
                        formattedDate: _formatDate(trip['start_time']),
                      )),
                const SizedBox(height: 24),

                // Recent feedback
                _SectionTitle(title: 'Feedback ล่าสุด'),
                const SizedBox(height: 10),
                if (_recentFeedback.isEmpty)
                  const _EmptyState(text: 'ยังไม่มี feedback')
                else
                  ..._recentFeedback.map((fb) => _RecentFeedbackTile(
                        feedback: fb,
                        formattedDate: _formatDate(fb['created_at']),
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                '$unit • $label',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTripTile extends StatelessWidget {
  const _RecentTripTile({required this.trip, required this.formattedDate});
  final Map<String, dynamic> trip;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final profile = trip['profiles'] as Map<String, dynamic>?;
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final distance = trip['distance'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, size: 18, color: Color(0xFF047857)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip['destination'] ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${profile?['display_name'] ?? '-'} • ${vehicle?['vehicle_plate'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              if (distance is num)
                Text(
                  '${distance.toDouble().toStringAsFixed(1)} กม.',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentFeedbackTile extends StatelessWidget {
  const _RecentFeedbackTile({required this.feedback, required this.formattedDate});
  final Map<String, dynamic> feedback;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final profile = feedback['profiles'] as Map<String, dynamic>?;
    final type = feedback['type'] ?? 'other';

    IconData icon;
    Color color;
    switch (type) {
      case 'bug':
        icon = Icons.bug_report_rounded;
        color = const Color(0xFFDC2626);
        break;
      case 'feature':
        icon = Icons.lightbulb_rounded;
        color = const Color(0xFF2563EB);
        break;
      case 'improvement':
        icon = Icons.build_rounded;
        color = const Color(0xFF047857);
        break;
      default:
        icon = Icons.notes_rounded;
        color = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback['message'] ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  profile?['display_name'] ?? '-',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
            3,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
            2,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 1 ? 10 : 0),
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
