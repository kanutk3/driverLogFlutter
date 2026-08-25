import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// ดึง role ของ user ปัจจุบันจาก profiles table
  Future<String> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'driver';
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return (profile?['role'] as String?) ?? 'driver';
    } catch (_) {
      return 'driver';
    }
  }

  /// ตรวจสอบว่าเป็น developer หรือไม่
  Future<bool> isDeveloper() async {
    final role = await getUserRole();
    return role == 'developer' || role == 'admin';
  }

  /// ตรวจสอบว่าเป็น admin หรือไม่
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
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

    // Login ทุกครั้ง: อัปเดตเฉพาะ google_name (display_name เป็นหน้าที่ของผู้ใช้)
    await _supabase.from('profiles').update({
      'email': user.email,
      'google_name': googleName,
    }).eq('id', user.id);
  }
}
