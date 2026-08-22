import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onboarding tour shown to new drivers on first app launch.
///
/// Stores a flag in secure storage so it only shows once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _storage = const FlutterSecureStorage();

  static const _pages = [
    _OnboardingPage(
      icon: Icons.add_road_rounded,
      iconColor: Color(0xFF2563EB),
      title: 'บันทึกเที่ยวรถ',
      description: 'กรอกข้อมูลเที่ยวรถ:\nทะเบียน, เลขไมล์, ตั๋ว, ค่าทางด่วน\nแล้วกด "จบการเดินทาง" เมื่อถึงจุดหมาย',
    ),
    _OnboardingPage(
      icon: Icons.edit_document,
      iconColor: Color(0xFF7C3AED),
      title: 'แก้ไขข้อมูล',
      description: 'แตะที่รายการ trip เพื่อดูรายละเอียด\nแล้วกด ✏️ "แก้ไข" เพื่อเปลี่ยนแปลงข้อมูล\nหรือกด 🗑️ "ลบ" เพื่อลบรายการ',
    ),
    _OnboardingPage(
      icon: Icons.ios_share_rounded,
      iconColor: Color(0xFF059669),
      title: 'ส่งออกรายงาน',
      description: 'ไปที่แท็บ "Export"\nเลือกช่วงวันที่ → ดาวน์โหลด PDF/JPG\nเพื่อส่งรายงานให้หัวหน้า',
    ),
    _OnboardingPage(
      icon: Icons.fingerprint_rounded,
      iconColor: Color(0xFFD97706),
      title: 'ล็อกอินด้วยลายนิ้วมือ',
      description: 'ล็อกอินด้วย Google ครั้งแรก\nแล้วไปเปิด "ล็อกอินด้วยลายนิ้วมือ"\nที่แท็บตั้งค่า → ครั้งถัดไปล็อกอินเร็วขึ้น!',
    ),
  ];

  Future<void> _complete() async {
    await _storage.write(key: 'onboarding_completed', value: 'true');
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: const Text('ข้าม', style: TextStyle(fontSize: 16)),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Next / Done button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _complete();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'ถัดไป' : 'เริ่มใช้งาน',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
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
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to check if onboarding has been completed.
Future<bool> isOnboardingCompleted() async {
  const storage = FlutterSecureStorage();
  final value = await storage.read(key: 'onboarding_completed');
  return value == 'true';
}
