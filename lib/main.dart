import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/driver_home_screen.dart';
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

  void _syncGoogleProfile(String userId) {
    if (_syncedUserId == userId) return;

    _syncedUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService().syncGoogleProfile();
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

        return const DriverHomeScreen();
      },
    );
  }
}