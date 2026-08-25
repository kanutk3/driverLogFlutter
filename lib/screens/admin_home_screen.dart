import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard_screen.dart';
import 'admin_user_manage_screen.dart';
import 'admin_feedback_manage_screen.dart';
import 'admin_vehicle_manage_screen.dart';

/// Main workspace for admin role.
///
/// Wraps admin-specific screens in a [NavigationBar] shell.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;

  User? get _user => _supabase.auth.currentUser;

  String get _displayName {
    final metadata = _user?.userMetadata;
    return (metadata?['full_name'] ?? metadata?['name'] ?? 'Admin').toString();
  }

  String? get _avatarUrl {
    final metadata = _user?.userMetadata;
    return metadata?['avatar_url'] ?? metadata?['picture'];
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
            // Logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626), // สีแดงสำหรับ admin
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: 'driver',
                    style: TextStyle(color: Color(0xFF0F172A)),
                  ),
                  TextSpan(
                    text: 'Log',
                    style: TextStyle(color: Color(0xFF2563EB)),
                  ),
                  TextSpan(
                    text: ' Admin',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Avatar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: '',
              offset: const Offset(0, 48),
              onSelected: (value) async {
                if (value == 'signOut') {
                  await _supabase.auth.signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: SizedBox(
                    width: 200,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFEE2E2),
                          backgroundImage: _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                          child: _avatarUrl == null
                              ? const Icon(Icons.person, color: Color(0xFFDC2626), size: 18)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'signOut',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: Colors.redAccent),
                    title: Text('ออกจากระบบ', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFEE2E2),
                backgroundImage: _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                child: _avatarUrl == null
                    ? const Icon(Icons.person, color: Color(0xFFDC2626), size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminDashboardScreen(),
          AdminUserManageScreen(),
          AdminFeedbackManageScreen(),
          AdminVehicleManageScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black12,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: '仪表板',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'คนขับ',
          ),
          NavigationDestination(
            icon: Icon(Icons.feedback_outlined),
            selectedIcon: Icon(Icons.feedback_rounded),
            label: 'Feedback',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car_rounded),
            label: 'รถ',
          ),
        ],
      ),
    );
  }
}
