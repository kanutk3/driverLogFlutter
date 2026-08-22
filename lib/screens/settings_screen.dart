import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/biometric_service.dart';

/// Settings / account management screen.
///
/// When [embedded] is true the AppBar is hidden (used inside a tab shell).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _biometricService = BiometricService();

  bool _isLoading = true;
  bool _biometricAvailable = false;
  bool _biometricRegistered = false;
  bool _isToggling = false;

  User? get _user => _supabase.auth.currentUser;

  String get _displayName {
    final metadata = _user?.userMetadata;
    return (metadata?['full_name'] ?? metadata?['name'] ?? 'คนขับ').toString();
  }

  String? get _avatarUrl {
    final metadata = _user?.userMetadata;
    return metadata?['avatar_url'] ?? metadata?['picture'];
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    setState(() => _isLoading = true);
    try {
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      if (_biometricAvailable) {
        _biometricRegistered = await _biometricService.hasRegisteredBiometric();
      }
    } catch (e) {
      debugPrint('Load biometric status error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      if (enable) {
        // Register biometric
        final success = await _biometricService.registerBiometric();
        if (success) {
          _biometricRegistered = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ผูกลายนิ้วมือสำเร็จ ✅'),
                backgroundColor: Color(0xFF047857),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ไม่สามารถผูกลายนิ้วมือได้'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        // Remove biometric
        await _biometricService.removeBiometric();
        _biometricRegistered = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เลิกผูกลายนิ้วมือแล้ว'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
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
                'ตั้งค่า',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Profile Card ─────────────────────────────
                      _buildProfileCard(),
                      const SizedBox(height: 24),

                      // ─── Security Section ─────────────────────────
                      const _SectionTitle(title: 'ความปลอดภัย'),
                      const SizedBox(height: 12),
                      _buildBiometricTile(),
                      const SizedBox(height: 24),

                      // ─── Account Section ──────────────────────────
                      const _SectionTitle(title: 'บัญชีผู้ใช้'),
                      const SizedBox(height: 12),
                      _buildSignOutTile(),
                    ],
                  ),
                ),
              ),
            ),
    );

    return widget.embedded ? scaffold : scaffold;
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage:
                _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
            child: _avatarUrl == null
                ? const Icon(Icons.person, color: Color(0xFF2563EB), size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _biometricRegistered
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: _biometricRegistered
                    ? const Color(0xFF047857)
                    : const Color(0xFF64748B),
                size: 26,
              ),
            ),
            title: Text(
              'ล็อกอินด้วยลายนิ้วมือ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _biometricAvailable
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
            ),
            subtitle: Text(
              _biometricAvailable
                  ? (_biometricRegistered
                      ? 'เปิดใช้งานแล้ว — ใช้ลายนิ้วมือเข้าสู่ระบบ'
                      : 'ล็อกอินเร็วขึ้นด้วยลายนิ้วมือ ไม่ต้องพิมพ์รหัสผ่าน')
                  : 'อุปกรณ์นี้ไม่รองรับการล็อกอินด้วยลายนิ้วมือ',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: _biometricAvailable
                ? Switch.adaptive(
                    value: _biometricRegistered,
                    onChanged: _isToggling ? null : _toggleBiometric,
                  )
                : null,
          ),
          if (_isToggling)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSignOutTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: const Text(
          'ออกจากระบบ',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('ออกจากระบบ?'),
              content: const Text('คุณต้องการออกจากระบบใช่หรือไม่'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('ออกจากระบบ'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await _supabase.auth.signOut();
          }
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
