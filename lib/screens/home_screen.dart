import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_dialog.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _biometricService = BiometricService();
  final _authService = AuthService();

  User? _currentUser;
  bool _biometricAvailable = false;

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
    _checkBiometric();

    _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
        });
      }
    });
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _biometricService.isBiometricAvailable();
      final registered = await _biometricService.hasRegisteredBiometric();
      if (mounted) {
        setState(() => _biometricAvailable = available && registered);
      }
    } catch (_) {}
  }

  Future<void> _loginWithBiometric() async {
    try {
      final success = await _biometricService.authenticate();
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('การยืนยันตัวตนล้มเหลว')),
          );
        }
        return;
      }

      // Use stored device credentials to login
      final deviceInfo = await DeviceService.getDeviceInfo();
      final email = 'dev_${deviceInfo.id.substring(0, 8)}@driverlog.com';
      await _authService.loginWithDevice(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เข้าสู่ระบบสำเร็จ ✅'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เข้าสู่ระบบล้มเหลว: $e')),
        );
      }
    }
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

                // 3. User Status Card (แสดงสถานะการล็อกอิน)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _currentUser != null ? Icons.check_circle : Icons.account_circle,
                        size: 64,
                        color: _currentUser != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUser != null
                            ? 'ยินดีต้อนรับคุณ $displayName'
                            : 'เริ่มต้นใช้งานระบบ',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser != null
                            ? 'คุณได้เข้าสู่ระบบและพร้อมสำหรับการบันทึกการเดินทางแล้ว'
                            : 'กรุณากดปุ่ม "เข้าสู่ระบบ" มุมบนขวาเพื่อผูกอุปกรณ์และเริ่มบันทึกงาน',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      if (_currentUser == null) ...[
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => showLoginDialog(context),
                          child: const Text(
                            'เข้าสู่ระบบทันที',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_biometricAvailable) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _loginWithBiometric,
                            icon: const Icon(Icons.fingerprint_rounded, size: 22),
                            label: const Text(
                              'ล็อกอินด้วยลายนิ้วมือ',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
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
class CustomAppLogo extends StatelessWidget {
  final double size;

  const CustomAppLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.directions_car,
            size: size * 0.6,
            color: Colors.white,
          ),
          Positioned(
            bottom: size * 0.15,
            child: Icon(
              Icons.assignment_turned_in,
              size: size * 0.3,
              color: const Color(0xFF60A5FA),
            ),
          ),
        ],
      ),
    );
  }
}