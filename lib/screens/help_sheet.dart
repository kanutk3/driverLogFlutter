import 'package:flutter/material.dart';

/// Bottom sheet showing quick help / how-to-use tips.
void showHelpSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _HelpSheetContent(),
  );
}

class _HelpSheetContent extends StatelessWidget {
  const _HelpSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '📖 วิธีใช้งาน driverLog',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
            _HelpItem(
              icon: Icons.add_road_rounded,
              iconColor: const Color(0xFF2563EB),
              title: 'บันทึกเที่ยวรถ',
              description: 'กดปุ่ม "เริ่มเลย" → กรอกข้อมูลเที่ยว → กด "จบการเดินทาง"',
            ),
            _HelpItem(
              icon: Icons.edit_document,
              iconColor: const Color(0xFF7C3AED),
              title: 'แก้ไขข้อมูล',
              description: 'ไปแท็บ "ล่าสุด" → แตะที่ trip → กด ✏️ แก้ไข → บันทึก',
            ),
            _HelpItem(
              icon: Icons.delete_outline,
              iconColor: const Color(0xFFDC2626),
              title: 'ลบข้อมูล',
              description: 'ไปแท็บ "ล่าสุด" → แตะที่ trip → กด 🗑️ ลบ → ยืนยัน',
            ),
            _HelpItem(
              icon: Icons.ios_share_rounded,
              iconColor: const Color(0xFF059669),
              title: 'ส่งออกรายงาน',
              description: 'ไปแท็บ "Export" → เลือกช่วงวันที่ → ดาวน์โหลด PDF/JPG',
            ),
            _HelpItem(
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'ล็อกอินด้วยลายนิ้วมือ',
              description: 'ไปแท็บ "ตั้งค่า" → เปิดลายนิ้วมือ → ยืนยัน → ครั้งถัดไปล็อกอินเร็วขึ้น!',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
