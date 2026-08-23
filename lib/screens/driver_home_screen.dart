import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_form_screen.dart';
import 'trip_history_screen.dart';
import 'trip_report_screen.dart';
import 'settings_screen.dart';
import 'help_sheet.dart';

/// Main workspace shown to an authenticated driver.
///
/// Wraps all top-level screens in a [BottomNavigationBar] shell so the user
/// can switch between Home, History, and Export without push/pop.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;

  final _supabase = Supabase.instance.client;

  // --- Profile helpers ---------------------------------------------------

  String? _profileName;

  User? get _user => _supabase.auth.currentUser;

  String get _displayName {
    if (_profileName != null && _profileName!.trim().isNotEmpty) {
      return _profileName!;
    }
    final metadata = _user?.userMetadata;
    return (metadata?['full_name'] ?? metadata?['name'] ?? 'คนขับ').toString();
  }

  String? get _avatarUrl {
    final metadata = _user?.userMetadata;
    return metadata?['avatar_url'] ?? metadata?['picture'];
  }

  @override
  void initState() {
    super.initState();
    _loadProfileName();
  }

  Future<void> _loadProfileName() async {
    final user = _user;
    if (user == null) return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(
            () => _profileName = profile?['display_name'] as String?);
      }
    } catch (_) {
      // Google profile name remains a safe fallback.
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ชื่อที่แสดงในรายงาน'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'ชื่อผู้ขับ',
            hintText: 'เช่น คุณจิ๋ว ตั้งมั่น',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == _displayName || _user == null) {
      return;
    }

    try {
      final List<dynamic> response = await _supabase
          .from('profiles')
          .update({'display_name': name})
          .eq('id', _user!.id)
          .select();

      if (!mounted) return;

      if (response.isNotEmpty) {
        setState(() => _profileName = name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกชื่อสำหรับรายงานแล้ว')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถแก้ไขข้อมูลได้ (ไม่มีสิทธิ์)')),
          );
        }
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${error.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกชื่อได้')),
        );
      }
    }
  }

  // --- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Row(
          children: [
            _BrandMark(size: 32),
            SizedBox(width: 10),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                      text: 'driver',
                      style: TextStyle(color: Color(0xFF0F172A))),
                  TextSpan(
                      text: 'Log',
                      style: TextStyle(color: Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: '',
              offset: const Offset(0, 48),
              onSelected: (value) async {
                if (value == 'editName') {
                  await _editDisplayName();
                } else if (value == 'signOut') {
                  await _supabase.auth.signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: SizedBox(
                    width: 230,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFEFF6FF),
                          backgroundImage: _avatarUrl == null
                              ? null
                              : NetworkImage(_avatarUrl!),
                          child: _avatarUrl == null
                              ? const Icon(Icons.person,
                                  color: Color(0xFF2563EB))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'editName',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('แก้ไขชื่อในรายงาน'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'signOut',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(
                      'ออกจากระบบ',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage:
                        _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                    child: _avatarUrl == null
                        ? const Icon(Icons.person,
                            color: Color(0xFF2563EB), size: 20)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),        body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            displayName: _displayName,
            onStartTrip: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TripFormScreen()),
              );
            },
          ),
          const TripHistoryScreen(embedded: true),
          TripReportScreen(embedded: true),
          const SettingsScreen(embedded: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showHelpSheet(context),
        backgroundColor: const Color(0xFF2563EB),
        tooltip: 'วิธีใช้งาน',
        child: const Icon(Icons.help_outline, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black12,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'ล่าสุด',
          ),
          NavigationDestination(
            icon: Icon(Icons.ios_share_outlined),
            selectedIcon: Icon(Icons.ios_share_rounded),
            label: 'รายงาน',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Home Tab — greeting card + today's summary + recent trips
// ============================================================================

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.displayName, required this.onStartTrip});

  final String displayName;
  final VoidCallback onStartTrip;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _recentTrips = [];
  _TodaySummary? _todaySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Load recent trips (last 5)
      final recent = await _supabase
          .from('trip_logs')
          .select('''
            id, ticket_number, destination, start_time, end_time,
            start_odometer, end_odometer, distance, toll_fee, ticket_price,
            vehicles(vehicle_plate, province)
          ''')
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(5);

      // Load today's trips for summary
      final todayStart = DateTime.now();
      final todayStartUtc = DateTime(
              todayStart.year, todayStart.month, todayStart.day)
          .toUtc();
      final todayEndUtc = DateTime(
              todayStart.year, todayStart.month, todayStart.day, 23, 59, 59)
          .toUtc();

      final todayTrips = await _supabase
          .from('trip_logs')
          .select('distance, ticket_price, toll_fee')
          .eq('user_id', userId)
          .gte('start_time', todayStartUtc.toIso8601String())
          .lte('start_time', todayEndUtc.toIso8601String());

      if (mounted) {
        setState(() {
          _recentTrips = List<Map<String, dynamic>>.from(recent);
          final count = todayTrips.length;
          final totalDistance = todayTrips.fold<double>(
              0,
              (sum, t) =>
                  sum + (t['distance'] is num ? t['distance'].toDouble() : 0));
          final totalCost = todayTrips.fold<double>(
              0,
              (sum, t) =>
                  sum +
                  (t['ticket_price'] is num
                      ? t['ticket_price'].toDouble()
                      : 0) +
                  (t['toll_fee'] is num ? t['toll_fee'].toDouble() : 0));
          _todaySummary = _TodaySummary(
            tripCount: count,
            totalDistance: totalDistance,
            totalCost: totalCost,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year + 543}';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // --- Greeting ---
              Text(
                'สวัสดี, ${widget.displayName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'พร้อมบันทึกการเดินทางสำหรับวันนี้',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
              const SizedBox(height: 28),

              // --- Primary action ---
              _PrimaryActionCard(onPressed: widget.onStartTrip),
              const SizedBox(height: 24),

              // --- Today's summary ---
              if (_isLoading)
                const _SummarySkeleton()
              else if (_todaySummary != null)
                _TodaySummaryCard(summary: _todaySummary!),
              const SizedBox(height: 24),

              // --- Recent trips ---
              const Text(
                'การเดินทางล่าสุด 5 เที่ยว',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const _TripSkeleton()
              else if (_recentTrips.isEmpty)
                const _EmptyTripState()
              else
                ..._recentTrips.map(
                  (trip) => _RecentTripCard(
                    trip: trip,
                    formatDate: _formatDate,
                    formatTime: _formatTime,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Today's Summary
// ============================================================================

class _TodaySummary {
  const _TodaySummary({
    required this.tripCount,
    required this.totalDistance,
    required this.totalCost,
  });

  final int tripCount;
  final double totalDistance;
  final double totalCost;
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.summary});

  final _TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wb_sunny_outlined,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'สรุปวันนี้',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (summary.tripCount == 0)
                const Text(
                  'ยังไม่มีเที่ยว',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
            ],
          ),
          if (summary.tripCount > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryStat(
                  icon: Icons.route_rounded,
                  value: '${summary.tripCount}',
                  unit: 'เที่ยว',
                ),
                const SizedBox(width: 20),
                _SummaryStat(
                  icon: Icons.speed_rounded,
                  value: summary.totalDistance.toStringAsFixed(1),
                  unit: 'กม.',
                ),
                const SizedBox(width: 20),
                _SummaryStat(
                  icon: Icons.payments_rounded,
                  value: summary.totalCost.toStringAsFixed(0),
                  unit: 'บาท',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Recent Trip Card
// ============================================================================

class _RecentTripCard extends StatelessWidget {
  const _RecentTripCard({
    required this.trip,
    required this.formatDate,
    required this.formatTime,
  });

  final Map<String, dynamic> trip;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  String _money(dynamic v) =>
      v is num ? v.toDouble().toStringAsFixed(0) : '-';

  @override
  Widget build(BuildContext context) {
    final startTime =
        DateTime.parse(trip['start_time'] as String).toLocal();
    final endTime = trip['end_time'] == null
        ? null
        : DateTime.parse(trip['end_time'] as String).toLocal();
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final plate = vehicle?['vehicle_plate'] as String? ?? '';
    final province = vehicle?['province'] as String?;
    final startOdo = trip['start_odometer']?.toString() ?? '-';
    final endOdo = trip['end_odometer']?.toString() ?? '-';
    final distance = trip['distance'] is num
        ? (trip['distance'] as num).toDouble()
        : null;
    final ticketPrice = trip['ticket_price'];
    final tollFee = trip['toll_fee'];
    final isDraft = endTime == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Row 1: Status + Date + Vehicle ---
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDraft
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDraft ? 'ร่าง' : 'จบแล้ว',
                    style: TextStyle(
                      color: isDraft
                          ? const Color(0xFFC2410C)
                          : const Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (plate.isNotEmpty)
                  Text(
                    '$plate${province == null ? '' : ' $province'}',
                    style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                const Spacer(),
                Text(
                  formatDate(startTime),
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- Destination ---
            Text(
              trip['destination'] as String? ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            // --- Time range ---
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 13, color: const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  endTime == null
                      ? formatTime(startTime)
                      : '${formatTime(startTime)} – ${formatTime(endTime)}',
                  style: const TextStyle(
                      color: Color(0xFF475569), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- Detail grid ---
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'เลขไมล์',
                    value: '$startOdo → $endOdo กม.',
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: 'ตั๋ว',
                    value: trip['ticket_number'] as String? ?? '-',
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: 'ค่าตั๋ว',
                    value: '${_money(ticketPrice)} บาท',
                  ),
                  if (tollFee != null &&
                      (tollFee is num ? tollFee.toDouble() : 0) > 0) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'ค่าทางด่วน',
                      value: '${_money(tollFee)} บาท',
                    ),
                  ],
                  if (distance != null) ...[
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'ระยะทาง',
                      value: '${distance.toStringAsFixed(1)} กม.',
                      valueBold: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Loading skeletons
// ============================================================================

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 100,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 20 : 0),
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripSkeleton extends StatelessWidget {
  const _TripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: 140 + i * 30.0,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Shared widgets
// ============================================================================

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child:
                Icon(Icons.add_road_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เริ่มบันทึกการเดินทาง',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'บันทึกเลขไมล์ ตั๋ว และปลายทางของเที่ยวรถ',
                  style: TextStyle(color: Color(0xFFDBEAFE)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
            ),
            child: const Text('เริ่มเลย'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTripState extends StatelessWidget {
  const _EmptyTripState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.route_outlined, size: 42, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('ยังไม่มีรายการเดินทาง',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(
            'เริ่มบันทึกเที่ยวแรกของคุณได้จากปุ่มด้านบน',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(size * .25),
      ),
      child: Icon(Icons.directions_car_rounded,
          size: size * .62, color: Colors.white),
    );
  }
}
