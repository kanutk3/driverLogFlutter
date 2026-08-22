import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

void showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const LoginDialog(),
  );
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _nameController = TextEditingController();
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _showDeviceForm = false;

  @override
  void initState() {
    super.initState();
    _checkExistingDevice();
  }

  /// ตรวจสอบว่า Device ID นี้เคยลงทะเบียนไว้ในระบบหรือยัง
  Future<void> _checkExistingDevice() async {
    try {
      final deviceInfo = await DeviceService.getDeviceInfo();

      // ค้นหาข้อมูลเครื่องในตาราง user_devices
      final response = await _supabase
          .from('user_devices')
          .select('user_id, profiles(display_name)')
          .eq('device_id', deviceInfo.id)
          .maybeSingle();

      if (response != null) {
        // ถ้าเจอเครื่องนี้ในระบบ ให้สั่ง Login เข้าใช้งานด้วย Device ID ทันที
        await _authService.loginWithDevice(
          email: 'dev_${deviceInfo.id.substring(0, 8)}@driverlog.com',
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เข้าสู่ระบบอัตโนมัติสำเร็จ')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Check device error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeviceRegister() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อผู้ใช้งาน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerPrimaryDevice(
        displayName: _nameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลงทะเบียนและเข้าสู่ระบบสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'เข้าสู่ระบบ driverLog',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 320,
        child: _isLoading
            ? const SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'กำลังตรวจสอบข้อมูลอุปกรณ์...',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showDeviceForm) ...[
                      // 1. LINE Login
                      // OutlinedButton.icon(

                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: const Color(0xFF06C755),
                      //     foregroundColor: Colors.white,
                      //     minimumSize: const Size(double.infinity, 45),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(8),
                      //     ),
                      //   ),
                      //   icon: const Icon(Icons.chat_bubble),
                      //   label: const Text('เข้าสู่ระบบด้วย LINE'),
                      //   onPressed: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(
                      //         content: Text('ระบบ LINE Login กำลังถูกพัฒนา'),
                      //       ),
                      //     );
                      //   },
                      // ),


                      // const SizedBox(height: 10),

                      // 2. Google Login
                      ElevatedButton.icon(

                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.g_mobiledata,
                            size: 30, color: Colors.red),
                        label: const Text('เข้าสู่ระบบด้วย Google',
                            style: TextStyle(color: Colors.black87)),
                        onPressed: () async {
                          try {
                            await _authService.loginWithGoogle();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Google Login error: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('หรือ',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Device Login Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueGrey,
                        ),
                        icon: const Icon(Icons.phonelink_setup),
                        label: const Text('ลงทะเบียนเครื่องใหม่ด้วย Device ID'),
                        onPressed: () {
                          setState(() {
                            _showDeviceForm = true;
                          });
                        },
                      ),
                    ] else ...[
                      // ฟอร์มสำหรับลงทะเบียน Device ID ใหม่
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ระบุชื่อผู้ใช้งาน / ชื่อคนขับ *',
                          hintText: 'เช่น สมชาย ขยันขับ',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showDeviceForm = false;
                                });
                              },
                              child: const Text('ย้อนกลับ'),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _handleDeviceRegister,
                              child: const Text('ตกลง'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}