import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'developer_trip_detail_screen.dart';

/// Developer screen to view all trip logs with filters.
class DeveloperTripLogsScreen extends StatefulWidget {
  const DeveloperTripLogsScreen({super.key});

  @override
  State<DeveloperTripLogsScreen> createState() =>
      _DeveloperTripLogsScreenState();
}

class _DeveloperTripLogsScreenState extends State<DeveloperTripLogsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  String? _selectedDriverId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // โหลดรายชื่อคนขับทั้งหมด (สำหรับ filter)
      final driversData = await _supabase
          .from('profiles')
          .select('id, display_name, google_name, email')
          .eq('role', 'driver')
          .order('display_name');

      // โหลด trip_logs
      var query = _supabase.from('trip_logs').select('''
            *,
            profiles(display_name, google_name, email),
            vehicles(vehicle_plate, brand)
          ''');

      if (_selectedDriverId != null) {
        query = query.eq('user_id', _selectedDriverId!);
      }

      if (_startDate != null) {
        query = query.gte('start_time', _startDate!.toIso8601String());
      }

      if (_endDate != null) {
        // เพิ่ม 1 วันเพื่อ cover ทั้งวัน
        final end = _endDate!.add(const Duration(days: 1));
        query = query.lt('start_time', end.toIso8601String());
      }

      final tripsData =
          await query.order('start_time', ascending: false).limit(200);

      if (mounted) {
        setState(() {
          _drivers = List<Map<String, dynamic>>.from(driversData);
          _trips = List<Map<String, dynamic>>.from(tripsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDriverId = null;
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadData();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadData();
    }
  }

  double get _totalDistance {
    double sum = 0;
    for (final trip in _trips) {
      final d = trip['distance'];
      if (d is num) sum += d.toDouble();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        _buildFilterBar(),

        // Summary
        if (!_isLoading && _trips.isNotEmpty)
          _buildSummary(),

        // Trip list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _trips.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) =>
                            _TripLogCard(trip: _trips[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final hasFilter =
        _selectedDriverId != null || _startDate != null || _endDate != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Driver filter
                _buildDriverDropdown(),
                const SizedBox(width: 8),
                // Start date
                _buildDateChip(
                  label: _startDate != null
                      ? DateFormat('dd/MM/yyyy').format(_startDate!)
                      : 'วันเริ่ม',
                  icon: Icons.calendar_today,
                  onTap: _pickStartDate,
                ),
                const SizedBox(width: 8),
                // End date
                _buildDateChip(
                  label: _endDate != null
                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                      : 'วันสิ้นสุด',
                  icon: Icons.calendar_today,
                  onTap: _pickEndDate,
                ),
                // Clear filters
                if (hasFilter) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('ล้างตัวกรอง',
                        style: TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.close, size: 14),
                    onPressed: _clearFilters,
                    backgroundColor: const Color(0xFFFEE2E2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDriverId,
          hint: const Text('🚗 คนขับทั้งหมด',
              style: TextStyle(fontSize: 12)),
          isDense: true,
          isExpanded: false,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('🚗 คนขับทั้งหมด', style: TextStyle(fontSize: 12)),
            ),
            ..._drivers.map((d) => DropdownMenuItem(
                  value: d['id'] as String,
                  child: Text(
                    d['display_name'] ?? d['google_name'] ?? d['email'] ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() => _selectedDriverId = value);
            _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: 'เที่ยว', value: '${_trips.length}'),
          _SummaryItem(
              label: 'ระยะทางรวม',
              value: '${_totalDistance.toStringAsFixed(1)} กม.'),
          _SummaryItem(label: 'คนขับ', value: '${_drivers.length}'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'ไม่มีข้อมูลเที่ยว',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ลองเปลี่ยนตัวกรอง',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF047857),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _TripLogCard extends StatelessWidget {
  const _TripLogCard({required this.trip});
  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final profile = trip['profiles'] as Map<String, dynamic>?;
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final distance = trip['distance'];
    final startTime = trip['start_time'];

    String formatTime(String? iso) {
      if (iso == null) return '-';
      try {
        final dt = DateTime.parse(iso).toLocal();
        return DateFormat('dd/MM HH:mm').format(dt);
      } catch (_) {
        return iso;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeveloperTripDetailScreen(trip: trip),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.route_rounded,
                    size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip['destination'] ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${profile?['display_name'] ?? profile?['google_name'] ?? '-'} • ${vehicle?['vehicle_plate'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Distance + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (distance is num)
                    Text(
                      '${distance.toDouble().toStringAsFixed(1)} กม.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    formatTime(startTime),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
