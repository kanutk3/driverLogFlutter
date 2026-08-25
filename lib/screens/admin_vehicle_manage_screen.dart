import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin screen to manage all vehicles — add, edit, delete.
class AdminVehicleManageScreen extends StatefulWidget {
  const AdminVehicleManageScreen({super.key});

  @override
  State<AdminVehicleManageScreen> createState() => _AdminVehicleManageScreenState();
}

class _AdminVehicleManageScreenState extends State<AdminVehicleManageScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('vehicles')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditVehicle({Map<String, dynamic>? existing}) async {
    final plateCtrl = TextEditingController(text: existing?['vehicle_plate'] ?? '');
    final brandCtrl = TextEditingController(text: existing?['brand'] ?? '');
    final modelCtrl = TextEditingController(text: existing?['model'] ?? '');
    final provinceCtrl = TextEditingController(text: existing?['province'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'เพิ่มรถใหม่' : 'แก้ไขรถ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(labelText: 'ทะเบียนรถ *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brandCtrl,
                decoration: const InputDecoration(labelText: 'ยี่ห้อ'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'รุ่น'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: provinceCtrl,
                decoration: const InputDecoration(labelText: 'จังหวัด'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (plateCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกทะเบียนรถ'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    try {
      final payload = {
        'vehicle_plate': plateCtrl.text.trim(),
        'brand': brandCtrl.text.trim(),
        'model': modelCtrl.text.trim(),
        'province': provinceCtrl.text.trim(),
      };

      if (existing == null) {
        await _supabase.from('vehicles').insert(payload);
      } else {
        await _supabase.from('vehicles').update(payload).eq('id', existing['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'เพิ่มรถสำเร็จ' : 'แก้ไขรถสำเร็จ'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        _loadVehicles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรถ ${vehicle['vehicle_plate']} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('vehicles').delete().eq('id', vehicle['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบรถสำเร็จ'), backgroundColor: Color(0xFF047857)),
        );
        _loadVehicles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('ยังไม่มีรถ', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('กดปุ่ม + เพื่อเพิ่มรถใหม่', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final v = _vehicles[index];
                      return _VehicleCard(
                        vehicle: v,
                        onEdit: () => _addOrEditVehicle(existing: v),
                        onDelete: () => _deleteVehicle(v),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditVehicle(),
        tooltip: 'เพิ่มรถ',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final plate = vehicle['vehicle_plate'] ?? '-';
    final brand = vehicle['brand'] ?? '';
    final model = vehicle['model'] ?? '';
    final province = vehicle['province'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Car icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [brand, model, province].where((s) => s.isNotEmpty).join(' ').isEmpty
                        ? '-'
                        : [brand, model, province].where((s) => s.isNotEmpty).join(' '),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            // Actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
              tooltip: 'แก้ไข',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
              tooltip: 'ลบ',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
