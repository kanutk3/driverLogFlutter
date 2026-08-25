import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin screen to manage all users — edit roles, delete accounts.
class AdminUserManageScreen extends StatefulWidget {
  const AdminUserManageScreen({super.key});

  @override
  State<AdminUserManageScreen> createState() => _AdminUserManageScreenState();
}

class _AdminUserManageScreenState extends State<AdminUserManageScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      var query = _supabase.from('profiles').select('*');

      if (_filterRole != 'all') {
        query = query.eq('role', _filterRole);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    try {
      await _supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยน role เป็น $newRole สำเร็จ'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบผู้ใช้ ${user['display_name'] ?? user['email']} ใช่หรือไม่?'),
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
      // ลบ profiles (ไม่ลบ auth user เพราะต้องสิทธิ์ admin ระดับ service role)
      await _supabase.from('profiles').delete().eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบผู้ใช้สำเร็จ'), backgroundColor: Color(0xFF047857)),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFDC2626);
      case 'developer':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return '👑 Admin';
      case 'developer':
        return '🛠️ Developer';
      default:
        return '🚗 Driver';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Text('กรอง: ', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _buildFilterChip('all', 'ทั้งหมด'),
              _buildFilterChip('driver', '🚗 คนขับ'),
              _buildFilterChip('developer', '🛠️ Dev'),
              _buildFilterChip('admin', '👑 Admin'),
            ],
          ),
        ),

        // User list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('ไม่มีผู้ใช้ในกลุ่มนี้', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _UserManageCard(
                            user: user,
                            roleColor: _roleColor((user['role'] ?? 'driver')),
                            roleLabel: _roleLabel((user['role'] ?? 'driver')),
                            formattedDate: _formatDate(user['created_at']),
                            onChangeRole: (newRole) => _changeRole(user, newRole),
                            onDelete: () => _deleteUser(user),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterRole == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterRole = value);
          _loadUsers();
        },
        selectedColor: const Color(0xFFDBEAFE),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _UserManageCard extends StatelessWidget {
  const _UserManageCard({
    required this.user,
    required this.roleColor,
    required this.roleLabel,
    required this.formattedDate,
    required this.onChangeRole,
    required this.onDelete,
  });

  final Map<String, dynamic> user;
  final Color roleColor;
  final String roleLabel;
  final String formattedDate;
  final Function(String) onChangeRole;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final currentRole = (user['role'] as String?) ?? 'driver';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Text(
                    (user['display_name'] ?? user['google_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['display_name'] ?? user['google_name'] ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        user['email'] ?? '-',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
                  tooltip: 'ลบผู้ใช้',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Role + date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'สมัคร: $formattedDate',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                // Role selector
                PopupMenuButton<String>(
                  tooltip: 'เปลี่ยน role',
                  offset: const Offset(0, 32),
                  onSelected: onChangeRole,
                  itemBuilder: (context) => [
                    if (currentRole != 'driver')
                      const PopupMenuItem(value: 'driver', child: Text('🚗 Driver')),
                    if (currentRole != 'developer')
                      const PopupMenuItem(value: 'developer', child: Text('🛠️ Developer')),
                    if (currentRole != 'admin')
                      const PopupMenuItem(value: 'admin', child: Text('👑 Admin')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('เปลี่ยน role', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
