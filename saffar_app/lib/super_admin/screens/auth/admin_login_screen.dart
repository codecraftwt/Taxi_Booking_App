import 'package:flutter/material.dart';
import 'package:saffar_app/super_admin/core/admin_api_service.dart';
import 'package:saffar_app/super_admin/core/admin_theme.dart';
import 'package:saffar_app/super_admin/screens/shell/admin_shell_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController(text: 'admin@saffar.com');
  final _passwordController = TextEditingController(text: 'AdminPassword@2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AdminApiService.instance.login(email, password);
      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminShellScreen()),
        );
      } else {
        setState(() => _errorMessage = res['message'] ?? 'Authentication failed.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed. Please check backend connection and credentials.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: Center(
        child: Container(
          width: isDesktop ? 960 : 440,
          height: isDesktop ? 580 : null,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(23, 32, 51, 0.08),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Brand Panel (Desktop only)
              if (isDesktop)
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: const BoxDecoration(
                      color: AdminTheme.secondaryBlue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AdminTheme.primaryOrange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'SAFFAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '🛡️ SUPER ADMIN PORTAL',
                            style: TextStyle(
                              color: AdminTheme.primaryOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Central Fleet & Platform Operations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Monitor drivers in real-time, verify compliance documents, manage dynamic city fares, and oversee platform financials with complete authority.',
                          style: TextStyle(
                            color: Color(0xFFBAC4D4),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '© 2026 Saffar Technologies Pvt Ltd. Authorized Access Only.',
                          style: TextStyle(color: Color(0xFF6E7E99), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

              // Right Form Panel
              Expanded(
                flex: isDesktop ? 5 : 1,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 48 : 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isDesktop) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminTheme.primaryOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.local_taxi, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'SAFFAR ADMIN',
                              style: TextStyle(
                                color: AdminTheme.secondaryBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to access your administrative operations dashboard.',
                        style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AdminTheme.errorBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminTheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AdminTheme.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AdminTheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Text(
                        'Work Email',
                        style: TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'admin@saffar.com',
                          prefixIcon: Icon(Icons.email_outlined, color: AdminTheme.textSecondary, size: 20),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Password',
                        style: TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: AdminTheme.textSecondary, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AdminTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Sign In to Dashboard',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

