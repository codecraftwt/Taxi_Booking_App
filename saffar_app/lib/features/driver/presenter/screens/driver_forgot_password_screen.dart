import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_reset_password_screen.dart';

class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({Key? key, this.initialPhone}) : super(key: key);

  static const String routeName = '/driver_forgot_password';

  final String? initialPhone;

  @override
  State<DriverForgotPasswordScreen> createState() => _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState extends State<DriverForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneController.text.trim();
    setState(() => _isLoading = true);

    try {
      final res = await context.read<DriverCubit>().forgotPassword(phone);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Driver account verified! Enter new password.'),
          backgroundColor: const Color(0xFF219653),
        ),
      );

      Navigator.pushNamed(
        context,
        DriverResetPasswordScreen.routeName,
        arguments: {
          'phone': res['phone']?.toString() ?? phone,
          'resetToken': res['reset_token']?.toString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('CustomException: ', '')),
          backgroundColor: Palette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Nums.horizontalPadding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Palette.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: Palette.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recover Driver Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your registered driver phone number to reset your password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Phone Input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Registered Mobile Number',
                      hintText: '9876543210',
                      prefixText: '+91 ',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter registered mobile number';
                      }
                      if (val.trim().length != 10 || int.tryParse(val.trim()) == null) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Nums.roundedCornerRadius),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify Driver Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Back to Sign In
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Remember password? Back to Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

