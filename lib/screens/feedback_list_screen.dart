import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// Screen for developer to view and reply to all feedback from users.
class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key});

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String _filterType = 'all';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);

    try {
      // Query feedback without JOIN (avoids profiles RLS issue)
      var query = _supabase.from('feedback').select('*');

      if (_filterType != 'all') {
        query = query.eq('type', _filterType);
      }

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final data = await query.order('created_at', ascending: false);
      final feedbackList = List<Map<String, dynamic>>.from(data);

      // Fetch profiles separately for user names
      final userIds = feedbackList
          .map((f) => f['user_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('profiles')
              .select('id, display_name, email')
              .inFilter('id', userIds);
          for (final p in profiles) {
            profileMap[p['id'] as String] = p;
          }
        } catch (_) {
          // profiles query failed — show feedback without names
        }
      }

      // Merge profile data into feedback
      for (final fb in feedbackList) {
        final uid = fb['user_id'] as String?;
        if (uid != null && profileMap.containsKey(uid)) {
          fb['profiles'] = profileMap[uid];
        }
      }

      if (mounted) {
        setState(() {
          _feedbacks = feedbackList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _replyToFeedback(Map<String, dynamic> feedback) async {
    final replyController = TextEditingController(
        text: feedback['developer_reply'] ?? '');
    final status = feedback['status'] ?? 'new';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ReplyDialog(
        replyController: replyController,
        initialStatus: status,
      ),
    );

    if (result == null) return;

    try {
      await _supabase.from('feedback').update({
        'developer_reply': result['reply'],
        'status': result['status'],
        'replied_at': DateTime.now().toIso8601String(),
        'replied_by': _supabase.auth.currentUser?.id,
      }).eq('id', feedback['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกสำเร็จ'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        _loadFeedbacks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.redAccent,
          ),
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

  String _statusLabel(String? status) {
    switch (status) {
      case 'reviewed':
        return '👀 ตรวจสอบแล้ว';
      case 'resolved':
        return '✅ แก้ไขแล้ว';
      case 'rejected':
        return '❌ ปฏิเสธ';
      default:
        return '🆕 ใหม่';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'reviewed':
        return const Color(0xFF2563EB);
      case 'resolved':
        return const Color(0xFF047857);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatDate(String iso) {
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
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type filter
              Row(
                children: [
                  const Text('ประเภท: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 6),
                  _buildFilterChip('all', 'ทั้งหมด', _filterType,
                      (v) => setState(() => _filterType = v)),
                  _buildFilterChip('bug', '🐛 บั๊ก', _filterType,
                      (v) => setState(() => _filterType = v)),
                  _buildFilterChip('feature', '💡 ฟีเจอร์', _filterType,
                      (v) => setState(() => _filterType = v)),
                  _buildFilterChip('improvement', '⚙️ ปรับปรุง',
                      _filterType, (v) => setState(() => _filterType = v)),
                ],
              ),
              const SizedBox(height: 8),
              // Status filter
              Row(
                children: [
                  const Text('สถานะ: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 6),
                  _buildFilterChip('all', 'ทั้งหมด', _filterStatus,
                      (v) => setState(() => _filterStatus = v)),
                  _buildFilterChip('new', '🆕 ใหม่', _filterStatus,
                      (v) => setState(() => _filterStatus = v)),
                  _buildFilterChip('reviewed', '👀 ตรวจสอบแล้ว',
                      _filterStatus,
                      (v) => setState(() => _filterStatus = v)),
                  _buildFilterChip('resolved', '✅ แก้ไขแล้ว', _filterStatus,
                      (v) => setState(() => _filterStatus = v)),
                ],
              ),
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
                          Icon(Icons.feedback_outlined,
                              size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('ยังไม่มี feedback',
                              style: TextStyle(fontWeight: FontWeight.w700)),
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
                          final profile =
                              fb['profiles'] as Map<String, dynamic>?;
                          return _FeedbackCard(
                            feedback: fb,
                            profile: profile,
                            typeLabel: _typeLabel(fb['type'] ?? 'other'),
                            typeColor: _typeColor(fb['type'] ?? 'other'),
                            statusLabel:
                                _statusLabel(fb['status']),
                            statusColor:
                                _statusColor(fb['status']),
                            formattedDate:
                                _formatDate(fb['created_at'] ?? ''),
                            onReply: () => _replyToFeedback(fb),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
      String value, String label, String current, Function(String) onTap) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) => onTap(value),
        selectedColor: const Color(0xFFDBEAFE),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.profile,
    required this.typeLabel,
    required this.typeColor,
    required this.statusLabel,
    required this.statusColor,
    required this.formattedDate,
    required this.onReply,
  });

  final Map<String, dynamic> feedback;
  final Map<String, dynamic>? profile;
  final String typeLabel;
  final Color typeColor;
  final String statusLabel;
  final Color statusColor;
  final String formattedDate;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final hasReply = feedback['developer_reply'] != null &&
        (feedback['developer_reply'] as String).isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type + status + date
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (feedback['app_version'] != null)
                  Text(
                    'v${feedback['app_version']}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                const Spacer(),
                Text(
                  formattedDate,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User info
            if (profile != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    profile?['display_name'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile?['email'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Message
            Text(
              feedback['message'] ?? '-',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                height: 1.5,
              ),
            ),

            // Contact
            if (feedback['contact'] != null &&
                (feedback['contact'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contact_phone_outlined,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      feedback['contact'],
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],

            // Developer reply
            if (hasReply) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.reply_rounded,
                            size: 14, color: Color(0xFF047857)),
                        SizedBox(width: 4),
                        Text(
                          'คำตอบจาก Developer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feedback['developer_reply'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Reply button
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: Text(hasReply ? 'แก้ไขคำตอบ' : 'ตอบกลับ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({
    required this.replyController,
    required this.initialStatus,
  });

  final TextEditingController replyController;
  final String initialStatus;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ตอบกลับ Feedback'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status selector
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'สถานะ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('🆕 ใหม่')),
                DropdownMenuItem(
                    value: 'reviewed', child: Text('👀 ตรวจสอบแล้ว')),
                DropdownMenuItem(
                    value: 'resolved', child: Text('✅ แก้ไขแล้ว')),
                DropdownMenuItem(value: 'rejected', child: Text('❌ ปฏิเสธ')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'new'),
            ),
            const SizedBox(height: 16),
            // Reply text
            TextField(
              controller: widget.replyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'คำตอบ',
                hintText: 'พิมพ์คำตอบให้ผู้ใช้...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'reply': widget.replyController.text,
            'status': _status,
          }),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
