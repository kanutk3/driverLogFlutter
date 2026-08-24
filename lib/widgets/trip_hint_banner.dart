import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A dismissable hint banner shown to first-time users.
/// Explains that trips can be edited by tapping on them.
class TripHintBanner extends StatefulWidget {
  const TripHintBanner({super.key});

  @override
  State<TripHintBanner> createState() => _TripHintBannerState();
}

class _TripHintBannerState extends State<TripHintBanner> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _checkHint();
  }

  Future<void> _checkHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('trip_hint_dismissed') ?? false;
    if (dismissed && mounted) {
      setState(() => _visible = false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trip_hint_dismissed', true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF2563EB), size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '💡 แตะที่รายการ trip เพื่อดูรายละเอียด แก้ไข หรือลบ',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1E40AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
          ),
        ],
      ),
    );
  }
}
