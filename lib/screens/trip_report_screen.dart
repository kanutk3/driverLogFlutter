import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/jpg_download.dart';
import '../config.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class TripReportScreen extends StatefulWidget {
  const TripReportScreen({
    super.key,
    this.initialRange,
    this.initialSearch = '',
    this.initialStatus = 'all',
    this.initialVehicleId,
    this.embedded = false,
    this.displayNameNotifier,
  });

  /// When true the screen renders without its own [AppBar] / bottom bar so
  /// it can live inside a parent shell (e.g. a [BottomNavigationBar]).
  final bool embedded;

  final DateTimeRange? initialRange;
  final String initialSearch;
  final String initialStatus;
  final String? initialVehicleId;

  /// Notifier เพื่อรับแจ้งเมื่อเปลี่ยนชื่อ → regenerate รายงาน
  final ValueNotifier<String?>? displayNameNotifier;

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  static const _rowsPerPage = 16;
  final _supabase = Supabase.instance.client;
  late DateTimeRange _range;
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isSharing = false;
  List<GlobalKey> _pageKeys = [];
  String _driverName = '';
  late String _search;
  late String _status;
  late String? _vehicleId;

  @override
  void initState() {
    super.initState();
    _loadDriverName();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = widget.initialRange ?? DateTimeRange(start: today, end: today);
    _search = widget.initialSearch;
    _status = widget.initialStatus;
    _vehicleId = widget.initialVehicleId;
    _loadTrips();

    // ฟังการเปลี่ยนชื่อ → regenerate รายงาน
    widget.displayNameNotifier?.addListener(_onDisplayNameChanged);
  }

  @override
  void dispose() {
    widget.displayNameNotifier?.removeListener(_onDisplayNameChanged);
    super.dispose();
  }

  void _onDisplayNameChanged() {
    // เมื่อเปลี่ยนชื่อ → โหลดชื่อใหม่แล้ว regenerate รายงาน
    _loadDriverName().then((_) {
      if (mounted) setState(() {});  // Rebuild รายงาน
    });
  }

  Future<void> _loadDriverName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // ใช้ชื่อจาก Google (userMetadata) เป็น fallback
    final fallback = (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? user.email ?? 'คนขับ').toString();

    try {
      // อ่านจาก profiles.display_name (ชื่อที่ผู้ใช้แก้ไขเอง)
      final profile = await _supabase
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = profile?['display_name'] as String?;
      if (mounted) setState(() => _driverName = (name == null || name.trim().isEmpty) ? fallback : name);
    } catch (_) {
      if (mounted) setState(() => _driverName = fallback);
    }
  }

  Future<void> _loadTrips() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final start = DateUtils.dateOnly(_range.start);
      final end = DateUtils.dateOnly(_range.end).add(const Duration(days: 1));
      var query = _supabase
          .from('trip_logs')
          .select('id, vehicle_id, ticket_number, destination, start_odometer, end_odometer, start_time, end_time, distance, toll_fee, ticket_price, vehicles(vehicle_plate, brand, model, province)')
          .eq('user_id', userId)
          .gte('start_time', start.toUtc().toIso8601String())
          .lt('start_time', end.toUtc().toIso8601String());
      if (_vehicleId != null) query = query.eq('vehicle_id', _vehicleId!);
      final response = await query.order('start_time');
      final needle = _search.trim().toLowerCase();
      final trips = List<Map<String, dynamic>>.from(response).where((trip) {
        final isDraft = trip['end_time'] == null;
        if (_status == 'draft' && !isDraft) return false;
        if (_status == 'completed' && isDraft) return false;
        if (needle.isEmpty) return true;
        return (trip['destination'] as String? ?? '').toLowerCase().contains(needle) ||
            (trip['ticket_number'] as String? ?? '').toLowerCase().contains(needle);
      }).toList();
      if (mounted) {
        setState(() {
          _trips = _ordered(trips);
          _pageKeys = List.generate(_pageCount, (_) => GlobalKey());
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _ordered(List<Map<String, dynamic>> trips) {
    final result = List<Map<String, dynamic>>.from(trips);
    result.sort((a, b) => DateTime.parse(a['start_time'] as String)
        .compareTo(DateTime.parse(b['start_time'] as String)));
    return result;
  }

  int get _pageCount => _trips.isEmpty ? 0 : (_trips.length / _rowsPerPage).ceil();

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() => _range = selected);
    _loadTrips();
  }

  Future<void> _export() async {
    if (_pageKeys.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      for (var index = 0; index < _pageKeys.length; index++) {
        final boundary = _pageKeys[index].currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) continue;
        await downloadJpg(
          bytes.buffer.asUint8List(),
          'driverlog_${_range.start.toIso8601String().substring(0, 10)}_to_${_range.end.toIso8601String().substring(0, 10)}_page-${index + 1}.jpg',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ดาวน์โหลดรายงาน $_pageCount หน้าแล้ว')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถสร้าง JPG ได้')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List?> _pagePngBytes(int index) async {
    final boundary = _pageKeys[index].currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<void> _sharePage(int index) async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _pagePngBytes(index);
      if (bytes == null) throw StateError('ไม่พบหน้ารายงาน');
      final filename = 'driverlog_${_range.start.toIso8601String().substring(0, 10)}_to_${_range.end.toIso8601String().substring(0, 10)}_page-${index + 1}.jpg';
      final shared = await shareJpg(bytes, filename);
      if (!shared && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เบราว์เซอร์นี้ยังไม่รองรับการแชร์ไฟล์ โปรดดาวน์โหลด JPG ก่อน')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถแชร์ JPG ได้')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _reportPage(int index) {
    final start = index * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _trips.length).toInt();
    return _ReportPage(
      trips: _trips.sublist(start, end),
      allTrips: _trips,
      range: _range,
      page: index + 1,
      totalPages: _pageCount,
      date: _date,
      driverName: _driverName,
    );
  }

  void _showFullScreenPreview(int index) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            title: Text('ตัวอย่างหน้า ${index + 1} • ใช้สองนิ้วซูม'),
            actions: [
              IconButton(
                tooltip: 'แชร์ JPG',
                onPressed: _isSharing ? null : () => _sharePage(index),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          body: InteractiveViewer(
            constrained: false,
            minScale: 0.25,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(600),
            child: _reportPage(index),
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year + 543}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Export รายงาน JPG'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              actions: [
                IconButton(onPressed: _chooseRange, icon: const Icon(Icons.date_range_outlined), tooltip: 'เลือกช่วงวันที่'),
              ],
            ),
      bottomNavigationBar: widget.embedded
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading || _trips.isEmpty || _isExporting ? null : _export,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(_isExporting ? 'กำลังสร้าง...' : 'ดาวน์โหลด JPG'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading || _trips.isEmpty || _isSharing ? null : () => _sharePage(0),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(_isSharing ? 'กำลังแชร์...' : 'แชร์หน้า 1'),
                  ),
                ),
              ]),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseRange,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('${_date(_range.start)} – ${_date(_range.end)}'),
                ),
                const SizedBox(height: 12),
                Text('พบ ${_trips.length} รายการ • ${_pageCount == 0 ? 0 : _pageCount} หน้า', style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 20),
                if (_trips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Column(children: [Icon(Icons.image_not_supported_outlined, size: 48), SizedBox(height: 12), Text('ไม่มีรายการในช่วงวันที่เลือก')]),
                  )
                else
                  ...List.generate(_pageCount, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: () => _showFullScreenPreview(index),
                        child: Column(children: [
                          FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            child: RepaintBoundary(
                              key: _pageKeys[index],
                              child: _reportPage(index),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('แตะรายงานเพื่อขยายและซูม • หน้า ${index + 1}', style: const TextStyle(color: Color(0xFF64748B))),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _ReportPage extends StatelessWidget {
  const _ReportPage({required this.trips, required this.allTrips, required this.range, required this.page, required this.totalPages, required this.date, required this.driverName});

  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> allTrips;
  final DateTimeRange range;
  final int page;
  final int totalPages;
  final String Function(DateTime) date;
  final String driverName;
  static final NumberFormat _moneyFormat = NumberFormat('#,##0');


  String _time(String? value) {
    if (value == null) return '-';
    final time = DateTime.parse(value).toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;

  String _dayKey(Map<String, dynamic> trip) {
    final value = DateTime.parse(trip['start_time'] as String).toLocal();
    return '${value.year}-${value.month}-${value.day}';
  }

  int _tripSequence(Map<String, dynamic> trip) =>
      allTrips.where((item) => _dayKey(item) == _dayKey(trip)).toList().indexWhere(
            (item) => item['id'] == trip['id'],
          ) +
      1;

  Map<String, dynamic>? get _vehicle {
    for (final trip in trips) {
      final value = trip['vehicles'];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = trips.fold<double>(0, (sum, trip) => sum + _number(trip['distance']));
    final totalTicket = trips.fold<double>(0, (sum, trip) => sum + _number(trip['ticket_price']));
    final vehicle = _vehicle;
    final plate = vehicle?['vehicle_plate'] as String? ?? '-';

    final vehicleType = [vehicle?['brand'], vehicle?['model']]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' ');
    return SizedBox(
      width: 1123,
      height: 794,
      child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 22),
          child: DefaultTextStyle(
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 118,
                child: Stack(children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.directions_car_rounded, color: Color(0xFF2563EB), size: 32),
                      SizedBox(width: 8),
                      Text('driverLog', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('ใบรายงานพนักงานขับรถ', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${date(range.start)} – ${date(range.end)}'),
                    ]),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      width: 365,
                      child: Table(
                        border: TableBorder.all(color: const Color(0xFF64748B)),
                        columnWidths: const {0: FixedColumnWidth(94), 1: FlexColumnWidth()},
                        children: [
                          _infoRow('ประเภทรถ', vehicleType.isEmpty ? '-' : vehicleType),
                          _infoRow('ทะเบียนรถ', plate),
                          _infoRow('ชื่อผู้ขับ', driverName.isEmpty ? '-' : driverName),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(color: const Color(0xFF64748B)),
                columnWidths: const {
                  0: FixedColumnWidth(74), // DATE
                  1: FixedColumnWidth(38), // C/T
                  2: FixedColumnWidth(82), // เลขที่ตั๋ว
                  3: FixedColumnWidth(68), // ราคาตั๋ว: คอลัมน์ใหม่
                  4: FixedColumnWidth(55), // เริ่มต้น
                  5: FlexColumnWidth(3),   // ปลายทาง
                  6: FixedColumnWidth(68), // เลขกิโลไป
                  7: FixedColumnWidth(50), // เวลาออก
                  8: FixedColumnWidth(68), // เลขกิโลกลับ
                  9: FixedColumnWidth(50), // เวลากลับ
                  10: FixedColumnWidth(58), // ทางด่วน
                  11: FixedColumnWidth(66), // หมายเหตุ
                },
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                    children: [
                        _Header('DATE'), 
                        _Header('C/T'), 
                        _Header('เลขที่ตั๋ว'), 
                        _Header('ราคาตั๋ว'), 
                        _Header('เริ่มต้น'), 
                        _Header('ปลายทาง'), 
                        _Header('เลขกิโลไป'), 
                        _Header('เวลา'), 
                        _Header('เลขกิโลกลับ'), 
                        _Header('เวลา'),
                        _Header('ทางด่วน'), 
                        _Header('REMARK')
                       ],
                  ),
                  ...List.generate(trips.length, (index) {
                    final trip = trips[index];
                    final isNewDay = index == 0 || _dayKey(trips[index - 1]) != _dayKey(trip);
                    return TableRow(
                      decoration: isNewDay && index > 0 ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF0F172A), width: 2))) : null,
                      children: [
                        _Cell(isNewDay ? date(DateTime.parse(trip['start_time'] as String).toLocal()) : ''),
                        _Cell(_tripSequence(trip).toString(), centered: true),
                        _Cell(trip['ticket_number'] as String? ?? '-'),
                        _Cell(
                          trip['ticket_price'] == null
                              ? '-'
                              : _moneyFormat.format(
                                  _number(trip['ticket_price']),
                                ),
                          right: true,
                        ),
                        const _Cell('AP', centered: true),
                        _Cell(trip['destination'] as String? ?? '-'),
                        _Cell(trip['start_odometer']?.toString() ?? '-', right: true),
                        _Cell(_time(trip['start_time'] as String?), centered: true),
                        _Cell(trip['end_odometer']?.toString() ?? '-', right: true),
                        _Cell(_time(trip['end_time'] as String?), centered: true),
                        _Cell(_number(trip['toll_fee']).toStringAsFixed(0), right: true),
                        const _Cell(''),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: Text('รวม ${trips.length} รายการ  •  ${totalDistance.toStringAsFixed(1)} กม.  •  ค่าตั๋ว ${_moneyFormat.format(totalTicket)} บาท', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              const Spacer(),
              const Divider(color: Color(0xFFCBD5E1)),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(5),
                    color: Colors.white,
                    child: QrImageView(
                      data: AppConfig.websiteShortUrl,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      gapless: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'สแกนเพื่อเข้าสู่เว็บไซต์ driverLog',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppConfig.websiteShortUrl.replaceFirst('https://', ''),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'รายงานนี้สร้างโดย driverLog',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (totalPages > 1) ...[
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: Text('หน้า $page / $totalPages', style: const TextStyle(color: Color(0xFF64748B)))),
              ],
            ]),
          ),
      ),
    );
  }
}

TableRow _infoRow(String label, String value) => TableRow(children: [
      _InfoCell(label, emphasized: true),
      _InfoCell(value),
    ]);

class _InfoCell extends StatelessWidget {
  const _InfoCell(this.text, {this.emphasized = false});
  final String text;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(text, style: TextStyle(fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400)),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(8), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)));
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.centered = false, this.right = false});
  final String text;
  final bool centered;
  final bool right;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : (right ? TextAlign.right : TextAlign.left),
        ),
      );
}
