import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

/// Screen for sending feedback, bug reports, or suggestions to the developer.
///
/// When [embedded] is true the AppBar is hidden (used inside a tab shell).
class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();
  String _feedbackType = 'bug';

  User? get _user => _supabase.auth.currentUser;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อความ'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      // Store feedback in Supabase (if table exists) or just show success
      await _supabase.from('feedback').insert({
        'user_id': _user?.id,
        'type': _feedbackType,
        'message': message,
        'contact': _contactController.text.trim(),
        'app_version': '1.0.0',
      });

      if (mounted) {
        _messageController.clear();
        _contactController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งข้อมูลสำเร็จแล้ว ขอบคุณครับ 🙏'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถส่งข้อมูลได้: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: const Text(
                'ส่งข้อมูลให้ผู้พัฒนา',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.feedback_outlined, color: Color(0xFF2563EB), size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ส่งความคิดเห็น',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'แจ้งบั๊ก, แนะนำฟีเจอร์, หรือติดต่อผู้พัฒนา',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Feedback type
                const Text('ประเภท', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildChip('bug', '🐛 แจ้งบั๊ก'),
                    _buildChip('feature', '💡 แนะนำฟีเจอร์'),
                    _buildChip('improvement', '⚙️ ปรับปรุง'),
                    _buildChip('other', '📝 อื่น ๆ'),
                  ],
                ),
                const SizedBox(height: 20),

                // Message
                const Text('รายละเอียด *', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'อธิบายปัญหาหรือข้อเสนอแนะ...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Contact
                const Text('ช่องทางติดต่อ (ถ้ามี)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    hintText: 'เบอร์โทร, LINE, หรือ email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sendFeedback,
                    icon: const Icon(Icons.send),
                    label: const Text('ส่งข้อมูล'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Contact info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ติดต่อผู้พัฒนา', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('📧 ${AppConfig.appUrl}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('🌐 driverLog - Driver Trip Recording App', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return widget.embedded ? scaffold : scaffold;
  }

  Widget _buildChip(String value, String label) {
    final isSelected = _feedbackType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _feedbackType = value);
      },
      selectedColor: const Color(0xFFDBEAFE),
    );
  }
}
