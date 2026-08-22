import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trip_form_screen.dart';
import 'trip_report_screen.dart';

enum _TripView { cards, table }

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.embedded = false});

  /// When true the screen renders without its own [AppBar] so it can live
  /// inside a parent shell (e.g. a [BottomNavigationBar]).
  final bool embedded;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _search = '';
  String _status = 'all';
  String? _vehicleId;
  DateTimeRange? _dateRange;
  _TripView _view = _TripView.cards;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('trip_logs')
          .select('''
            id,
            ticket_number,
            vehicle_id,
            destination,
            start_time,
            end_time,
            start_odometer,
            end_odometer,
            distance,
            toll_fee,
            ticket_price,
            vehicles(vehicle_plate, province)
          ''')
          .eq('user_id', userId)
          .order('start_time', ascending: false);

      if (mounted) {
        setState(() => _trips = List<Map<String, dynamic>>.from(response));
      }
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'ไม่สามารถโหลดประวัติการเดินทางได้');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;

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

  String _money(double value) => value.toStringAsFixed(0);

  DateTimeRange _exportRange(List<Map<String, dynamic>> trips) {
    if (_dateRange != null) return _dateRange!;
    if (trips.isEmpty) {
      final today = DateUtils.dateOnly(DateTime.now());
      return DateTimeRange(start: today, end: today);
    }
    final dates = trips
        .map((trip) => DateUtils.dateOnly(DateTime.parse(trip['start_time'] as String).toLocal()))
        .toList()
      ..sort();
    return DateTimeRange(start: dates.first, end: dates.last);
  }

  List<Map<String, dynamic>> get _filteredTrips {
    final needle = _search.trim().toLowerCase();
    return _trips.where((trip) {
      final isDraft = trip['end_time'] == null;
      if (_status == 'draft' && !isDraft) return false;
      if (_status == 'completed' && isDraft) return false;
      if (_vehicleId != null && trip['vehicle_id'] != _vehicleId) return false;
      final start = DateTime.parse(trip['start_time'] as String).toLocal();
      if (_dateRange != null &&
          (start.isBefore(DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day)) ||
              start.isAfter(DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59)))) {
        return false;
      }
      if (needle.isEmpty) return true;
      final destination = (trip['destination'] as String? ?? '').toLowerCase();
      final ticket = (trip['ticket_number'] as String? ?? '').toLowerCase();
      return destination.contains(needle) || ticket.contains(needle);
    }).toList();
  }

  Future<void> _editTrip(String tripId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TripFormScreen(tripId: tripId)),
    );
    if (changed == true) _loadTrips();
  }

  Future<void> _showFilters() async {
    final vehicles = <String, String>{};
    for (final trip in _trips) {
      final vehicle = trip['vehicles'] as Map<String, dynamic>?;
      final id = trip['vehicle_id'] as String?;
      if (id != null && vehicle != null) {
        vehicles[id] = '${vehicle['vehicle_plate']} ${vehicle['province'] ?? ''}';
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ตัวกรอง', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'สถานะ', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                  DropdownMenuItem(value: 'completed', child: Text('จบแล้ว')),
                  DropdownMenuItem(value: 'draft', child: Text('ร่าง')),
                ],
                onChanged: (value) => setSheetState(() => _status = value ?? 'all'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _vehicleId,
                decoration: const InputDecoration(labelText: 'รถ', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('รถทุกคัน')),
                  ...vehicles.entries.map((entry) => DropdownMenuItem<String?>(value: entry.key, child: Text(entry.value))),
                ],
                onChanged: (value) => setSheetState(() => _vehicleId = value),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_dateRange == null ? 'เลือกช่วงวันที่' : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}'),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: _dateRange,
                  );
                  if (range != null) setSheetState(() => _dateRange = range);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _status = 'all';
                        _vehicleId = null;
                        _dateRange = null;
                      });
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('ล้างตัวกรอง'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('แสดงผล'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = _filteredTrips;
    final totalDistance = trips.fold<double>(0, (sum, trip) => sum + _number(trip['distance']));
    final totalTicket = trips.fold<double>(0, (sum, trip) => sum + _number(trip['ticket_price']));
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final showTable = wide && _view == _TripView.table;
    final metadata = _supabase.auth.currentUser?.userMetadata;
    final avatarUrl = metadata?['avatar_url'] ?? metadata?['picture'];

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('ประวัติการเดินทาง'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: _showFilters, icon: const Icon(Icons.tune_rounded), tooltip: 'ตัวกรอง'),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripReportScreen(
                  initialRange: _exportRange(_filteredTrips),
                  initialSearch: _search,
                  initialStatus: _status,
                  initialVehicleId: _vehicleId,
                ),
              ),
            ),
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Export JPG',
          ),
          if (wide)
            IconButton(
              onPressed: () => setState(() => _view = showTable ? _TripView.cards : _TripView.table),
              icon: Icon(showTable ? Icons.view_agenda_outlined : Icons.table_rows_outlined),
              tooltip: showTable ? 'มุมมองรายการ' : 'มุมมองตาราง',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl as String),
              child: avatarUrl == null ? const Icon(Icons.person, size: 18, color: Color(0xFF2563EB)) : null,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _HistoryError(message: _errorMessage!, onRetry: _loadTrips)
                : trips.isEmpty
                    ? const _EmptyHistory()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                        children: [
                          _HistorySummary(
                            count: trips.length,
                            totalDistance: totalDistance,
                            totalTicket: totalTicket,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _search = value),
                            decoration: InputDecoration(
                              hintText: 'ค้นหาปลายทางหรือเลขตั๋ว',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'รายการเดินทาง',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          if (showTable)
                            _TripTable(trips: trips, formatDate: _formatDate, number: _number, onEdit: _editTrip)
                          else
                            ...trips.map((trip) => _TripHistoryCard(
                                  trip: trip,
                                  number: _number,
                                  formatDate: _formatDate,
                                  formatTime: _formatTime,
                                  money: _money,
                                  onEdit: () => _editTrip(trip['id'] as String),
                                )),
                        ],
                      ),
      ),
    );
    return scaffold;
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({
    required this.count,
    required this.totalDistance,
    required this.totalTicket,
  });

  final int count;
  final double totalDistance;
  final double totalTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.route_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count รายการ',
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'รวม ${totalDistance.toStringAsFixed(1)} กม.  •  ค่าตั๋ว ${totalTicket.toStringAsFixed(0)} บาท',
                  style: const TextStyle(color: Color(0xFFDBEAFE)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  const _TripHistoryCard({
    required this.trip,
    required this.number,
    required this.formatDate,
    required this.formatTime,
    required this.money,
    required this.onEdit,
  });

  final Map<String, dynamic> trip;
  final double Function(dynamic value) number;
  final String Function(DateTime value) formatDate;
  final String Function(DateTime value) formatTime;
  final String Function(double value) money;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(trip['start_time'] as String).toLocal();
    final endTime = trip['end_time'] == null ? null : DateTime.parse(trip['end_time'] as String).toLocal();
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final plate = vehicle?['vehicle_plate'] as String? ?? 'ไม่ระบุรถ';
    final province = vehicle?['province'] as String?;
    final distance = trip['distance'] == null ? null : number(trip['distance']);
    final isDraft = endTime == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDraft ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDraft ? 'ร่าง' : 'จบแล้ว',
                    style: TextStyle(
                      color: isDraft ? const Color(0xFFC2410C) : const Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(formatDate(startTime), style: const TextStyle(color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              trip['destination'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _TripMeta(icon: Icons.confirmation_number_outlined, text: trip['ticket_number'] as String? ?? '-'),
                _TripMeta(icon: Icons.directions_car_outlined, text: '$plate${province == null ? '' : ' $province'}'),
                _TripMeta(
                  icon: Icons.schedule_outlined,
                  text: endTime == null ? formatTime(startTime) : '${formatTime(startTime)} – ${formatTime(endTime)}',
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                Text(
                  distance == null ? 'ยังไม่สรุประยะทาง' : '${distance.toStringAsFixed(1)} กม.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${money(number(trip['ticket_price']))} บาท',
                  style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _TripTable extends StatelessWidget {
  const _TripTable({
    required this.trips,
    required this.formatDate,
    required this.number,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> trips;
  final String Function(DateTime value) formatDate;
  final double Function(dynamic value) number;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('ตั๋ว')),
            DataColumn(label: Text('รถ')),
            DataColumn(label: Text('ปลายทาง')),
            DataColumn(label: Text('ระยะทาง')),
            DataColumn(label: Text('ค่าตั๋ว')),
            DataColumn(label: Text('')),
          ],
          rows: trips.map((trip) {
            final vehicle = trip['vehicles'] as Map<String, dynamic>?;
            final start = DateTime.parse(trip['start_time'] as String).toLocal();
            return DataRow(
              onSelectChanged: (_) => onEdit(trip['id'] as String),
              cells: [
                DataCell(Text(formatDate(start))),
                DataCell(Text(trip['ticket_number'] as String? ?? '-')),
                DataCell(Text(vehicle?['vehicle_plate'] as String? ?? '-')),
                DataCell(SizedBox(width: 180, child: Text(trip['destination'] as String, overflow: TextOverflow.ellipsis))),
                DataCell(Text(trip['distance'] == null ? '-' : '${number(trip['distance']).toStringAsFixed(1)} กม.')),
                DataCell(Text('${number(trip['ticket_price']).toStringAsFixed(0)} บาท')),
                DataCell(IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'แก้ไข', onPressed: () => onEdit(trip['id'] as String))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TripMeta extends StatelessWidget {
  const _TripMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 100),
        Icon(Icons.history_rounded, size: 52, color: Color(0xFF94A3B8)),
        SizedBox(height: 16),
        Text(
          'ยังไม่มีประวัติการเดินทาง',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 6),
        Text(
          'รายการที่คุณบันทึกจะแสดงที่นี่',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off_outlined, size: 52, color: Color(0xFF94A3B8)),
        const SizedBox(height: 16),
        const Text('โหลดประวัติไม่สำเร็จ', textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง'))),
      ],
    );
  }
}
