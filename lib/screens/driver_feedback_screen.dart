import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'send_feedback_screen.dart';

/// Screen for driver to see their own feedback history + developer replies.
class DriverFeedbackScreen extends StatefulWidget {
  const DriverFeedbackScreen({super.key});

  @override
  State<DriverFeedbackScreen> createState() => _DriverFeedbackScreenState();
}

class _DriverFeedbackScreenState extends State<DriverFeedbackScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('feedback')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

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
        // Header with send button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'ความคิดเห็นของฉัน',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SendFeedbackScreen()),
                  );
                  _loadFeedbacks(); // refresh after sending
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ส่งใหม่'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Feedback list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _feedbacks.isEmpty
                  ? const _EmptyFeedback()
                  : RefreshIndicator(
                      onRefresh: _loadFeedbacks,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _feedbacks.length,
                        itemBuilder: (context, index) {
                          final fb = _feedbacks[index];
                          return _DriverFeedbackCard(
                            feedback: fb,
                            typeLabel: _typeLabel(fb['type'] ?? 'other'),
                            typeColor: _typeColor(fb['type'] ?? 'other'),
                            statusLabel: _statusLabel(fb['status']),
                            statusColor: _statusColor(fb['status']),
                            formattedDate: _formatDate(fb['created_at'] ?? ''),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _DriverFeedbackCard extends StatelessWidget {
  const _DriverFeedbackCard({
    required this.feedback,
    required this.typeLabel,
    required this.typeColor,
    required this.statusLabel,
    required this.statusColor,
    required this.formattedDate,
  });

  final Map<String, dynamic> feedback;
  final String typeLabel;
  final Color typeColor;
  final String statusLabel;
  final Color statusColor;
  final String formattedDate;

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
                    color: typeColor.withValues(alpha: 0.1),
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
                    color: statusColor.withValues(alpha: 0.1),
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
                const Spacer(),
                Text(
                  formattedDate,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
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
                          'คำตอบจากทีมงาน',
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
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.feedback_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text('ยังไม่มีความคิดเห็น',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'กดปุ่ม "ส่งใหม่" เพื่อส่งความคิดเห็นให้ทีมงาน',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
