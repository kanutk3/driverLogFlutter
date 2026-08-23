import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';
import '../config.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> registerPrimaryDevice({
    required String displayName,
    String? email,
  }) async {
    final deviceInfo = await DeviceService.getDeviceInfo();

    final finalEmail = (email != null && email.isNotEmpty)
        ? email
        : 'dev_${deviceInfo.id.substring(0, 8)}@driverlog.app.com';

    final password = 'pwd_${deviceInfo.id}';

    await _supabase.auth.signUp(
      email: finalEmail,
      password: password,
      data: {
        'display_name': displayName,
        'current_device_id': deviceInfo.id,
        'device_name': deviceInfo.name,
      },
    );
  }

  Future<void> loginWithDevice({required String email}) async {
    final deviceInfo = await DeviceService.getDeviceInfo();
    final password = 'pwd_${deviceInfo.id}';

    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> loginWithGoogle() async {
    // ตรวจสอบ origin จริงตอนรัน — ใช้ได้ทั้ง debug, release, localhost, production
    String redirectOrigin;
    if (kIsWeb) {
      redirectOrigin = Uri.base.origin;
    } else {
      redirectOrigin = AppConfig.appUrl;
    }
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectOrigin,
    );
  }

  Future<void> syncGoogleProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata;
    final googleName = (
      metadata?['full_name'] ??
      metadata?['name'] ??
      ''
    ).toString().trim();

    final existing = await _supabase
        .from('profiles')
        .select('id, display_name')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      // Login ครั้งแรก: เก็บทั้งชื่อ Google และชื่อที่ใช้แสดง
      await _supabase.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'google_name': googleName,
        'display_name': googleName,
        'role': 'driver',
      });
      return;
    }

    // Login ทุกครั้ง: อัปเดตชื่อจาก Google ทั้ง google_name และ display_name
    await _supabase.from('profiles').update({
      'email': user.email,
      'google_name': googleName,
      'display_name': googleName,
    }).eq('id', user.id);
  }
}
