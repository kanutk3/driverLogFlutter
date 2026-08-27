import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  User? _currentUser;

  String get displayName {
    return _currentUser?.userMetadata?['full_name'] ??
        _currentUser?.userMetadata?['name'] ??
        'Driver';
  }

  String? get avatarUrl {
    return _currentUser?.userMetadata?['avatar_url'] ??
        _currentUser?.userMetadata?['picture'];
  }

  @override
  void initState() {
    super.initState();
    _currentUser = _supabase.auth.currentUser;

    _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            // Logo เล็กบน AppBar
            const CustomAppLogo(size: 32),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'driver', style: TextStyle(color: Color(0xFF0F172A))),
                  TextSpan(text: 'Log', style: TextStyle(color: Color(0xFF2563EB))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _currentUser == null
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => showLoginDialog(context),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('เข้าสู่ระบบ', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                : Row(
                    children: [
                    
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: const Color(0xFF2563EB),
                          backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        label: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        tooltip: 'ออกจากระบบ',
                        onPressed: () async {
                          await _supabase.auth.signOut();
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. App Logo ใหญ่กลาง Landing Page
                const CustomAppLogo(size: 110),
                const SizedBox(height: 24),

                // 2. App Title & Headline
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(text: 'driver', style: TextStyle(color: Color(0xFF0F172A))),
                      TextSpan(text: 'Log', style: TextStyle(color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ระบบบันทึกและจัดการการเดินรถอัจฉริยะสำหรับคนขับมืออาชีพ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),

                // Feature Cards
                const Text(
                  'ฟีเจอร์หลัก',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text('ครบทุกสิ่งที่คนขับต้องการ', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: const [
                        _FeatureCard(icon: Icons.add_road_rounded, title: 'บันทึกเที่ยว', subtitle: 'บันทึกเลขไมล์ ปลายทาง\nและค่าใช้จ่าย', color: Color(0xFF2563EB)),
                        _FeatureCard(icon: Icons.speed_rounded, title: 'ติดตามระยะทาง', subtitle: 'ดูระยะทางรวม\nและสถิติรายวัน', color: Color(0xFF047857)),
                        _FeatureCard(icon: Icons.ios_share_rounded, title: 'ส่งออก JPG', subtitle: 'สร้างรายงานภาพ\nพร้อม QR Code', color: Color(0xFFC2410C)),
                        _FeatureCard(icon: Icons.history_rounded, title: 'ประวัติการเดินทาง', subtitle: 'ดูเที่ยวล่าสุด 5 เที่ยว\nพร้อมรายละเอียด', color: Color(0xFF7C3AED)),
                        _FeatureCard(icon: Icons.feedback_rounded, title: 'ส่ง Feedback', subtitle: 'แจ้งปัญหาหรือ\nแนะนำฟีเจอร์ใหม่', color: Color(0xFFDC2626)),
                        _FeatureCard(icon: Icons.help_outline_rounded, title: 'วิธีใช้งาน', subtitle: 'คู่มือการใช้งาน\nทีละขั้นตอน', color: Color(0xFF0891B2)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget สำหรับวาดโลโก้ driverLog (พวงมาลัย + สมุดบันทึก)
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
        ],
      ),
    );
  }
}

class CustomAppLogo extends StatelessWidget {
  final double size;

  const CustomAppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}