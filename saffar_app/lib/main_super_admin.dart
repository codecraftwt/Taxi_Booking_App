import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'super_admin/core/admin_theme.dart';
import 'super_admin/core/admin_api_service.dart';
import 'super_admin/screens/auth/admin_login_screen.dart';
import 'super_admin/screens/shell/admin_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment on native platforms (web blocks HTTP dotfiles)
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Super Admin: Could not load .env directly: $e");
    }
  }

  // Initialize Admin API Service
  AdminApiService.instance.init();

  runApp(const SaffarSuperAdminApp());
}

class SaffarSuperAdminApp extends StatelessWidget {
  const SaffarSuperAdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAFFAR — Super Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.themeData,
      home: AdminApiService.instance.isAuthenticated
          ? const AdminShellScreen()
          : const AdminLoginScreen(),
    );
  }
}

