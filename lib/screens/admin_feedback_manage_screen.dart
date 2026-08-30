import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Admin screen to view and delete all feedback.
class AdminFeedbackManageScreen extends StatefulWidget {
  const AdminFeedbackManageScreen({super.key});

  @override
  State<AdminFeedbackManageScreen> createState() => _AdminFeedbackManageScreenState();
}

class _AdminFeedbackManageScreenState extends State<AdminFeedbackManageScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);

    try {
      var query = _supabase
          .from('feedback')
          .select('*, profiles(display_name, email)');

      if (_filterType != 'all') {
        query = query.eq('type', _filterType);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _feedbacks = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFeedback(Map<String, dynamic> fb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบความคิดเห็นนี้ใช่หรือไม่?'),
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
      await _supabase.from('feedback').delete().eq('id', fb['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบความคิดเห็นสำเร็จ'), backgroundColor: Color(0xFF047857)),
        );
        _loadFeedbacks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bug':
        return '🐛 บั๊ก';
      case 'feature':
        return '💡 ฟีเจอร์';
      case 'improvement':
        return '⚙️ ปรับปรุง';
      default:
        return '📝 อื่น ๆ';
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'bug':
        return const Color(0xFFDC2626);
      case 'feature':
        return const Color(0xFF2563EB);
      case 'improvement':
        return const Color(0xFF047857);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
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
              _buildFilterChip('bug', '🐛 บั๊ก'),
              _buildFilterChip('feature', '💡 ฟีเจอร์'),
              _buildFilterChip('improvement', '⚙️ ปรับปรุง'),
              _buildFilterChip('other', '📝 อื่น ๆ'),
            ],
          ),
        ),

        // Feedback list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _feedbacks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.feedback_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('ยังไม่มีความคิดเห็น', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFeedbacks,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _feedbacks.length,
                        itemBuilder: (context, index) {
                          final fb = _feedbacks[index];
                          final profile = fb['profiles'] as Map<String, dynamic>?;
                          return _AdminFeedbackCard(
                            feedback: fb,
                            profile: profile,
                            typeLabel: _typeLabel(fb['type'] ?? 'other'),
                            typeColor: _typeColor(fb['type'] ?? 'other'),
                            formattedDate: _formatDate(fb['created_at']),
                            onDelete: () => _deleteFeedback(fb),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterType = value);
          _loadFeedbacks();
        },
        selectedColor: const Color(0xFFDBEAFE),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _AdminFeedbackCard extends StatelessWidget {
  const _AdminFeedbackCard({
    required this.feedback,
    required this.profile,
    required this.typeLabel,
    required this.typeColor,
    required this.formattedDate,
    required this.onDelete,
  });

  final Map<String, dynamic> feedback;
  final Map<String, dynamic>? profile;
  final String typeLabel;
  final Color typeColor;
  final String formattedDate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                if (feedback['app_version'] != null)
                  Text(
                    'v${feedback['app_version']}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'ลบ',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // User info
            if (profile != null)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    profile?['display_name'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile?['email'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Message
            Text(
              feedback['message'] ?? '-',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.5),
            ),

            // Contact
            if (feedback['contact'] != null &&
                (feedback['contact'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contact_phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      feedback['contact'],
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
