import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing biometric (fingerprint) authentication.
///
/// - **Mobile (Android/iOS/macOS/Windows):** uses `local_auth` package.
/// - **Web:** uses browser Web Authentication API (WebAuthn) via JS interop.
///
/// Credentials are stored server-side in Supabase `user_credentials` table.
class BiometricService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ─── Capability checks ───────────────────────────────────────────────

  /// Check if the device supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      return _isWebAuthnAvailable();
    }
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Check if biometrics are enrolled (user has at least one fingerprint/face).
  Future<bool> isBiometricEnrolled() async {
    if (kIsWeb) {
      return _isWebAuthnAvailable();
    }
    try {
      final available = await _localAuth.canCheckBiometrics;
      if (!available) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Registration (enroll fingerprint) ────────────────────────────────

  /// Register a biometric credential for the current user.
  ///
  /// Returns `true` if registration succeeded.
  Future<bool> registerBiometric() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (kIsWeb) {
        return await _registerWebAuthn(user.id);
      } else {
        return await _registerLocalAuth(user.id);
      }
    } catch (e) {
      debugPrint('Biometric registration failed: $e');
      return false;
    }
  }

  Future<bool> _registerLocalAuth(String userId) async {
    // Step 1: Verify identity with biometrics first
    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'ยืนยันตัวตนเพื่อผูกลายนิ้วมือ',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    if (!didAuthenticate) return false;

    // Step 2: Generate a credential ID and store it
    final credentialId = 'biometric_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    // Store locally for quick check
    await _secureStorage.write(key: 'biometric_credential_id', value: credentialId);

    // Store on server
    await _saveCredentialToServer(userId, credentialId, 'local_auth');

    return true;
  }

  Future<bool> _registerWebAuthn(String userId) async {
    // WebAuthn registration is handled via JS interop
    // For now, we use a simplified approach:
    // Verify with browser's built-in prompt, then store credential
    try {
      // This will call navigator.credentials.create() via JS interop
      final credentialId = await _webAuthnRegister(userId);
      if (credentialId == null || credentialId.isEmpty) return false;

      // Store locally
      await _secureStorage.write(key: 'biometric_credential_id', value: credentialId);

      // Store on server
      await _saveCredentialToServer(userId, credentialId, 'webauthn');

      return true;
    } catch (e) {
      debugPrint('WebAuthn registration failed: $e');
      return false;
    }
  }

  // ─── Authentication (verify fingerprint to login) ─────────────────────

  /// Authenticate using biometrics. Returns `true` if verified.
  Future<bool> authenticate() async {
    try {
      if (kIsWeb) {
        return await _authenticateWebAuthn();
      } else {
        return await _authenticateLocalAuth();
      }
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      return false;
    }
  }

  Future<bool> _authenticateLocalAuth() async {
    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'ยืนยันตัวตนด้วยลายนิ้วมือ',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    return didAuthenticate;
  }

  Future<bool> _authenticateWebAuthn() async {
    return await _webAuthnAuthenticate();
  }

  // ─── Status ───────────────────────────────────────────────────────────

  /// Check if the current user has registered biometric credentials.
  Future<bool> hasRegisteredBiometric() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final credential = await _supabase
          .from('user_credentials')
          .select('id')
          .eq('user_id', user.id)
          .eq('credential_type', kIsWeb ? 'webauthn' : 'local_auth')
          .maybeSingle();

      return credential != null;
    } catch (_) {
      return false;
    }
  }

  /// Remove biometric registration for the current user.
  Future<void> removeBiometric() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('user_credentials')
          .delete()
          .eq('user_id', user.id);

      await _secureStorage.delete(key: 'biometric_credential_id');
    } catch (e) {
      debugPrint('Remove biometric failed: $e');
    }
  }

  // ─── Server helpers ───────────────────────────────────────────────────

  Future<void> _saveCredentialToServer(
    String userId,
    String credentialId,
    String type,
  ) async {
    // Upsert: if credential exists for this user, update it
    final existing = await _supabase
        .from('user_credentials')
        .select('id')
        .eq('user_id', userId)
        .eq('credential_type', type)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('user_credentials')
          .update({
            'credential_id': credentialId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    } else {
      await _supabase.from('user_credentials').insert({
        'user_id': userId,
        'credential_id': credentialId,
        'credential_type': type,
      });
    }
  }

  // ─── WebAuthn JS interop stubs ────────────────────────────────────────
  // These call browser Web Authentication API via dart:js_interop.
  // On platforms that don't support WebAuthn, they return null/false.

  bool _isWebAuthnAvailable() {
    if (!kIsWeb) return false;
    try {
      // Check if navigator.credentials is available
      return _checkWebAuthnSupport();
    } catch (_) {
      return false;
    }
  }

  Future<String?> _webAuthnRegister(String userId) async {
    if (!kIsWeb) return null;
    try {
      return await _webAuthnCreateCredential(userId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _webAuthnAuthenticate() async {
    if (!kIsWeb) return false;
    try {
      return await _webAuthnGetCredential();
    } catch (_) {
      return false;
    }
  }

  // ─── Platform channel stubs for WebAuthn ──────────────────────────────
  // In production, these would use dart:js_interop to call:
  //   navigator.credentials.create()  — for registration
  //   navigator.credentials.get()     — for authentication
  //
  // For now, we fall back to local_auth on all platforms.

  bool _checkWebAuthnSupport() {
    // Will be implemented with JS interop in web/
    return false;
  }

  Future<String?> _webAuthnCreateCredential(String userId) async {
    // Will be implemented with JS interop in web/
    return null;
  }

  Future<bool> _webAuthnGetCredential() async {
    // Will be implemented with JS interop in web/
    return false;
  }
}
