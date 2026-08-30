import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.tripId});

  final String? tripId;

  bool get isEditing => tripId != null;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _ticketNumberController = TextEditingController();
  final _ticketPriceController = TextEditingController(text: '0');
  final _destinationController = TextEditingController();
  final _startOdometerController = TextEditingController();
  final _endOdometerController = TextEditingController();
  final _tollFeeController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  DateTime _startTime = DateTime.now();
  DateTime? _endTime;
  bool _isLoadingVehicles = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    if (widget.isEditing) _loadTrip();
  }

  @override
  void dispose() {
    _ticketNumberController.dispose();
    _ticketPriceController.dispose();
    _destinationController.dispose();
    _startOdometerController.dispose();
    _endOdometerController.dispose();
    _tollFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _supabase
          .from('vehicles')
          .select('id, vehicle_plate, province, brand, model')
          .order('vehicle_plate');
      final defaultVehicleId = await _loadDefaultVehicleId();

      if (mounted) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(vehicles);
          _selectedVehicleId = defaultVehicleId;
          _isLoadingVehicles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถโหลดรายการรถได้')),
        );
      }
    }
  }

  Future<void> _loadTrip() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || widget.tripId == null) return;

    try {
      final trip = await _supabase
          .from('trip_logs')
          .select('vehicle_id, ticket_number, ticket_price, destination, start_odometer, start_time, end_odometer, end_time, toll_fee')
          .eq('id', widget.tripId!)
          .eq('user_id', userId)
          .maybeSingle();
      if (trip == null || !mounted) return;

      setState(() {
        _selectedVehicleId = trip['vehicle_id'] as String?;
        _ticketNumberController.text = trip['ticket_number'] as String? ?? '';
        _ticketPriceController.text = trip['ticket_price'].toString();
        _destinationController.text = trip['destination'] as String? ?? '';
        _startOdometerController.text = trip['start_odometer'].toString();
        _startTime = DateTime.parse(trip['start_time'] as String).toLocal();
        _endOdometerController.text = trip['end_odometer']?.toString() ?? '';
        _endTime = trip['end_time'] == null ? null : DateTime.parse(trip['end_time'] as String).toLocal();
        _tollFeeController.text = trip['toll_fee'].toString();
      });
    } catch (_) {
      if (mounted) _showMessage('ไม่สามารถโหลดรายการที่ต้องการแก้ไขได้');
    }
  }

  Future<String?> _loadDefaultVehicleId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('default_vehicle_id')
          .eq('id', userId)
          .maybeSingle();
      return profile?['default_vehicle_id'] as String?;
    } catch (_) {
      // The trip form remains usable if the migration has not been run yet.
      return null;
    }
  }

  Future<void> _saveDefaultVehicle() async {
    try {
      await _supabase.rpc(
        'set_my_default_vehicle',
        params: {'p_vehicle_id': _selectedVehicleId},
      );
    } catch (_) {
      // A trip can still be recorded even when saving the preferred vehicle fails.
    }
  }

  double? get _distancePreview {
    final start = double.tryParse(_startOdometerController.text.trim());
    final end = double.tryParse(_endOdometerController.text.trim());
    if (start == null || end == null || end < start) return null;
    return end - start;
  }

  Future<void> _pickDateTime({required bool isStartTime}) async {
    final initial = isStartTime ? _startTime : (_endTime ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStartTime) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
    });
  }

  Future<void> _saveTrip({required bool isCompleted}) async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final startOdometer = double.parse(_startOdometerController.text.trim());
    final endOdometer = _endOdometerController.text.trim().isEmpty
        ? null
        : double.parse(_endOdometerController.text.trim());

    if (isCompleted && (endOdometer == null || _endTime == null)) {
      _showMessage('กรุณากรอกเลขไมล์และเวลาสิ้นสุดก่อนจบงาน');
      return;
    }
    if (endOdometer != null && endOdometer < startOdometer) {
      _showMessage('เลขไมล์สิ้นสุดต้องไม่น้อยกว่าเลขไมล์เริ่ม');
      return;
    }
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      _showMessage('เวลาสิ้นสุดต้องไม่ก่อนเวลาเริ่ม');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = {
        'vehicle_id': _selectedVehicleId,
        'ticket_number': _ticketNumberController.text.trim().isEmpty
            ? null
            : _ticketNumberController.text.trim(),
        'ticket_price': double.parse(_ticketPriceController.text.trim()),
        'destination': _destinationController.text.trim(),
        'start_odometer': startOdometer,
        'start_time': _startTime.toUtc().toIso8601String(),
        'end_odometer': endOdometer,
        'end_time': _endTime?.toUtc().toIso8601String(),
        'toll_fee': double.parse(_tollFeeController.text.trim()),
      };

      if (widget.isEditing) {
        await _supabase
            .from('trip_logs')
            .update(data)
            .eq('id', widget.tripId!)
            .eq('user_id', user.id);
      } else {
        await _supabase.from('trip_logs').insert({
          'user_id': user.id,
          ...data,
        });
      }

      await _saveDefaultVehicle();

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      _showMessage('บันทึกไม่สำเร็จ: ${error.message}');
    } catch (_) {
      _showMessage('บันทึกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year + 543}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.isEditing ? 'แก้ไขการเดินทาง' : 'บันทึกการเดินทาง'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : () => _saveTrip(isCompleted: true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                children: [
                  const Text(
                    'ข้อมูลตั๋ว',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    children: [
                      TextFormField(
                        controller: _ticketNumberController,
                        decoration: const InputDecoration(
                          labelText: 'เลขที่ตั๋ว *',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'กรุณากรอกเลขที่ตั๋ว'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ticketPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ราคาตั๋ว *',
                          suffixText: 'บาท',
                          prefixIcon: Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: _nonNegativeNumberValidator,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _destinationController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'ปลายทาง *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'กรุณาระบุปลายทาง'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'รถประจำและข้อมูลเริ่มต้น',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedVehicleId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'รถประจำ *',
                          helperText: 'ระบบจะจำรถคันนี้ไว้ในการบันทึกครั้งถัดไป',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                          border: OutlineInputBorder(),
                        ),
                        hint: Text(_isLoadingVehicles ? 'กำลังโหลดรถ...' : 'เลือกรถ'),
                        items: _vehicles
                            .map(
                              (vehicle) => DropdownMenuItem(
                                value: vehicle['id'] as String,
                                child: Text(
                                  '${vehicle['vehicle_plate']} ${vehicle['province'] ?? ''} '
                                  '— ${vehicle['brand']} ${vehicle['model']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isLoadingVehicles
                            ? null
                            : (value) => setState(() => _selectedVehicleId = value),
                        validator: (value) => value == null ? 'กรุณาเลือกรถ' : null,
                      ),
                      const SizedBox(height: 16),
                      _DateTimeField(
                        label: 'เวลาเริ่ม *',
                        value: _formatDateTime(_startTime),
                        onTap: () => _pickDateTime(isStartTime: true),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _startOdometerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'เลขไมล์เริ่ม *',
                          suffixText: 'กม.',
                          prefixIcon: Icon(Icons.speed_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: _numberValidator,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ค่าใช้จ่ายเพิ่มเติม',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    children: [
                      TextFormField(
                        controller: _tollFeeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'ค่าทางด่วน',
                          suffixText: 'บาท',
                          prefixIcon: Icon(Icons.toll_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: _nonNegativeNumberValidator,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ข้อมูลสิ้นสุดการเดินทาง',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    children: [
                      _DateTimeField(
                        label: 'เวลาสิ้นสุด',
                        value: _endTime == null ? 'ยังไม่ระบุ' : _formatDateTime(_endTime!),
                        onTap: () => _pickDateTime(isStartTime: false),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _endOdometerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'เลขไมล์สิ้นสุด',
                          suffixText: 'กม.',
                          prefixIcon: Icon(Icons.speed_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          return _numberValidator(value);
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_distancePreview != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'ระยะทางรวม ${_distancePreview!.toStringAsFixed(1)} กม.',
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  String? _numberValidator(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'กรุณากรอกตัวเลข';
    if (number < 0) return 'ค่าต้องไม่ติดลบ';
    return null;
  }

  String? _nonNegativeNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอกตัวเลข';
    return _numberValidator(value);
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_outlined),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }
}
