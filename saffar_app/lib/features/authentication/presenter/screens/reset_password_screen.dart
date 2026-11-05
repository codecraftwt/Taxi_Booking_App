import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/authentication/data/repositories/auth_repo.dart';
import 'package:saffar_app/features/user/data/models/user.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';
import 'package:saffar_app/wrapper.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    Key? key,
    this.phone,
    this.resetToken,
  }) : super(key: key);

  static const String routeName = '/reset_password';

  final String? phone;
  final String? resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthRepo _authRepo = sl<AuthRepo>();

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _logoutAllSessions = true;
  bool _isLoading = false;

  int _passwordStrength = 0; // 0..4
  bool _hasMinLength = false;
  bool _hasNumberOrSymbol = false;
  bool _hasUpperAndLower = false;

  late final TextEditingController _accountController;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.phone?.trim() ?? '');
    _newPasswordController.addListener(_validatePasswordCriteria);
    _accountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_validatePasswordCriteria);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _accountController.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _validatePasswordCriteria() {
    final text = _newPasswordController.text;
    final minLen = text.length >= 8;
    final numOrSym = RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(text);
    final upperLower = RegExp(r'[a-z]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text);

    int strength = 0;
    if (text.isNotEmpty) {
      if (text.length >= 4) strength = 1;
      if (minLen) strength = 2;
      if (minLen && numOrSym) strength = 3;
      if (minLen && numOrSym && upperLower) strength = 4;
    }

    setState(() {
      _hasMinLength = minLen;
      _hasNumberOrSymbol = numOrSym;
      _hasUpperAndLower = upperLower;
      _passwordStrength = strength;
    });
  }

  Future<void> _onResetPasswordPressed() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your registered phone number or email.'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match. Please re-enter.'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _authRepo.resetPassword(
        phone: account,
        newPassword: newPass,
        logoutAllSessions: _logoutAllSessions,
      );

      if (!mounted) return;

      final user = res['user'] as User?;
      final token = res['token'] as String?;

      if (user != null && token != null) {
        final userRepo = sl<UserRepo>();
        await userRepo.putUserMapInLocalStorage(user.toMap());
        await userRepo.putTokenInLocalStorage(token);
        if (mounted) {
          context.read<UserCubit>().emitUserAndToken(user, token);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Password reset successfully! Logged in.',
          ),
          backgroundColor: const Color(0xFF20A46B),
        ),
      );

      // Navigate to main application screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        Wrapper.routeName,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Palette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayAccountText {
    final raw = _accountController.text.trim();
    if (raw.isEmpty) return 'your registered account';
    if (!raw.contains('@') && !raw.startsWith('+')) {
      return '+91 $raw';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Top Bar: Back, Brand Icon + Sign In, Avatar
              _buildTopBar(context),

              const SizedBox(height: 20),

              // 2. Center Hero Key Graphic with Concentric Rings
              _buildHeroKey(),

              const SizedBox(height: 16),

              // 3. Headline & Subtitle
              const Text(
                'Set New Password',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF173B67),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Create a strong, new password for account $_displayAccountText. Ensure it differs from your previous passwords.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Account summary / input section
              _buildAccountSection(),

              // 4. New Password Input Field
              _buildNewPasswordField(),

              const SizedBox(height: 10),

              // 5. Strength Progress Bar & Live Checklist
              _buildStrengthSection(),

              const SizedBox(height: 20),

              // 6. Confirm New Password Field
              _buildConfirmPasswordField(),

              const SizedBox(height: 18),

              // 7. Active Sessions Logout Toggle
              _buildActiveSessionsToggle(),

              const SizedBox(height: 24),

              // 8. Reset Password & Log In Button
              _buildResetButton(),

              const SizedBox(height: 20),

              // 9. SSL Badge & Saffar Support Footnote
              _buildSecurityFooter(context),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Top Bar
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF173B67),
              size: 22,
            ),
          ),
        ),

        // Brand Icon & Sign In Text
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.near_me_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B67),
              ),
            ),
          ],
        ),

        // Avatar
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFF8B4513),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // 2. Hero Key / Refresh Graphic with Concentric Rings
  Widget _buildHeroKey() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outermost Glow Ring
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDD5).withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        // Middle Glow Ring
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEDD5),
            shape: BoxShape.circle,
          ),
        ),
        // Center Orange Key / Refresh
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFFF8500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.lock_reset_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        // Green Verified Shield Badge
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Account badge or input
  Widget _buildAccountSection() {
    final text = _accountController.text.trim();
    if (text.isNotEmpty) {
      final formatted = !text.contains('@') && !text.startsWith('+') ? '+91 $text' : text;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFFFF6B00),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF173B67),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _accountController.clear();
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registered Mobile Number or Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF173B67),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _accountController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Palette.neutral,
            ),
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.phone_iphone_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              hintText: 'Enter mobile number or email',
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 4. New Password Field
  Widget _buildNewPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF173B67),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _newPasswordController,
            focusNode: _newPasswordFocus,
            obscureText: !_newPasswordVisible,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Palette.neutral,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              hintText: 'Enter new password',
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _newPasswordVisible = !_newPasswordVisible);
                },
                icon: Icon(
                  _newPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // 5. Password Strength Bar & Requirements Checklist
  Widget _buildStrengthSection() {
    String strengthText = 'Weak';
    Color strengthColor = const Color(0xFFEF4444);

    switch (_passwordStrength) {
      case 1:
        strengthText = 'Weak';
        strengthColor = const Color(0xFFEF4444);
        break;
      case 2:
        strengthText = 'Fair';
        strengthColor = const Color(0xFFF59E0B);
        break;
      case 3:
        strengthText = 'Good';
        strengthColor = const Color(0xFF3B82F6);
        break;
      case 4:
        strengthText = 'Strong';
        strengthColor = const Color(0xFF10B981);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'STRENGTH',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              strengthText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 4-Segment Bar
        Row(
          children: List.generate(4, (index) {
            final active = _passwordStrength > index;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: active ? strengthColor : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 12),

        // Live Checklist
        _checklistRow(_hasMinLength, 'At least 8 characters'),
        const SizedBox(height: 6),
        _checklistRow(_hasNumberOrSymbol, 'Contains a number or symbol'),
        const SizedBox(height: 6),
        _checklistRow(_hasUpperAndLower, 'Contains uppercase & lowercase letters'),
      ],
    );
  }

  Widget _checklistRow(bool satisfied, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: satisfied
                ? const Color(0xFF10B981)
                : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: satisfied
                  ? const Color(0xFF10B981)
                  : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: satisfied
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 11,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: satisfied ? FontWeight.w700 : FontWeight.w500,
            color: satisfied ? const Color(0xFF173B67) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // 6. Confirm New Password Field
  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm New Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF173B67),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocus,
            obscureText: !_confirmPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onResetPasswordPressed(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Palette.neutral,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              hintText: 'Re-enter new password',
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() =>
                      _confirmPasswordVisible = !_confirmPasswordVisible);
                },
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // 7. Active Sessions Logout Toggle
  Widget _buildActiveSessionsToggle() {
    return InkWell(
      onTap: () {
        setState(() => _logoutAllSessions = !_logoutAllSessions);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _logoutAllSessions
                    ? const Color(0xFFFF6B00)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _logoutAllSessions
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: _logoutAllSessions
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log out of all other active sessions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF173B67),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Recommended if you suspect unauthorized device access.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 8. Reset Password & Log In Button
  Widget _buildResetButton() {
    return InkWell(
      onTap: _isLoading ? null : _onResetPasswordPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Reset Password & Log In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // 9. SSL Badge & Support Footnote
  Widget _buildSecurityFooter(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: Color(0xFF173B67),
              ),
              SizedBox(width: 5),
              Text(
                '256-Bit SSL Encrypted • Saffar Security Guaranteed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF173B67),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Need instant assistance? Contact ',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, UserSupportScreen.routeName);
              },
              child: const Text(
                'Saffar Support 24/7',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173B67),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
