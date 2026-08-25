import 'package:flutter/material.dart';
import '../services/auth_service.dart';

void showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LoginDialog(),
  );
}

class LoginDialog extends StatelessWidget {
  const LoginDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'เข้าสู่ระบบ driverLog',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ใช้บัญชี Google ของคุณเพื่อเข้าสู่ระบบ',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
              label: const Text(
                'เข้าสู่ระบบด้วย Google',
                style: TextStyle(color: Colors.black87, fontSize: 15),
              ),
              onPressed: () async {
                try {
                  await authService.loginWithGoogle();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Google Login error: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
