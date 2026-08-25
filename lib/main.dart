import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/developer_home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uubjrfumfytvhlzrbhji.supabase.co',
    publishableKey: 'sb_publishable_mr0HnOE24GTfeWAFGQPl_Q_EujERFHa',
  );

  runApp(const DriverLogApp());
}

class DriverLogApp extends StatelessWidget {
  const DriverLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'driverLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _syncedUserId;
  bool _showOnboarding = false;
  bool _onboardingChecked = false;
  String _userRole = 'driver';

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await isOnboardingCompleted();
    if (mounted) {
      setState(() {
        _showOnboarding = !completed;
        _onboardingChecked = true;
      });
    }
  }

  void _syncGoogleProfile(String userId) {
    if (_syncedUserId == userId) return;

    _syncedUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AuthService().syncGoogleProfile();
      // ดึง role หลัง sync profile
      final role = await AuthService().getUserRole();
      if (mounted) {
        setState(() => _userRole = role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? supabase.auth.currentSession;

        if (session == null) {
          _syncedUserId = null;
          return const HomeScreen();
        }

        _syncGoogleProfile(session.user.id);

        if (!_onboardingChecked) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_showOnboarding) {
          return OnboardingScreen(
            onComplete: () {
              setState(() => _showOnboarding = false);
            },
          );
        }

        // เช็ค role แล้วแสดงหน้าที่ถูกต้อง
        if (_userRole == 'admin') {
          return const AdminHomeScreen();
        }
        if (_userRole == 'developer') {
          return const DeveloperHomeScreen();
        }
        return const DriverHomeScreen();
      },
    );
  }
}