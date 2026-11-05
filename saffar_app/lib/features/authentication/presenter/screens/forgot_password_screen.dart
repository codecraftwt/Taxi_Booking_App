import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/authentication/data/repositories/auth_repo.dart';
import 'package:saffar_app/features/authentication/presenter/screens/reset_password_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key, this.initialPhone}) : super(key: key);

  static const String routeName = '/forgot_password';

  final String? initialPhone;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthRepo _authRepo = sl<AuthRepo>();
  late final TextEditingController _inputController;

  String _selectedChannel = 'phone'; // 'phone' or 'email'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: widget.initialPhone ?? '',
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _onSendResetLink() async {
    final value = _inputController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedChannel == 'phone'
                ? 'Please enter your mobile phone number.'
                : 'Please enter your registered email address.',
          ),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _authRepo.forgotPassword(
        phoneOrEmail: value,
        channel: _selectedChannel == 'phone' ? 'SMS' : 'Email',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ??
                'Reset verification code sent successfully to $value!',
          ),
          backgroundColor: const Color(0xFF20A46B),
        ),
      );

      // Navigate directly to Reset Password screen
      Navigator.pushNamed(
        context,
        ResetPasswordScreen.routeName,
        arguments: {
          'phone': res['phone'] ?? value,
          'resetToken': res['reset_token'],
        },
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
              // 1. Top Bar: Back, Brand Nav + Sign In, Avatar
              _buildTopBar(context),

              const SizedBox(height: 20),

              // 2. Glowing Shield Hero Graphic
              _buildHeroShield(),

              const SizedBox(height: 16),

              // 3. Title & Subtitle
              const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF173B67),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Enter your registered phone or email to receive an instant verification link and regain account access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Channel Selector
              _buildChannelSelector(),

              const SizedBox(height: 18),

              // 5. Input Field
              _buildInputField(),

              const SizedBox(height: 14),

              // 6. Security 15-Minute Expiration Notice Card
              _buildNoticeCard(),

              const SizedBox(height: 20),

              // 7. CTA Button
              _buildSendButton(),

              const SizedBox(height: 16),

              // 8. "Remember your password? Back to Login >"
              _buildBackToLoginLink(context),

              const SizedBox(height: 22),

              // 9. Help Desk Card
              _buildHelpCard(context),

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

  // 2. Hero Shield Graphic with Concentric Rings
  Widget _buildHeroShield() {
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
        // Center Orange Shield
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
              Icons.shield_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
        // Green Verified Checkmark Badge
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

  // 4. Channel Selector: Mobile Phone vs Email Address
  Widget _buildChannelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT RECOVERY CHANNEL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF6B00),
                  size: 14,
                ),
                Text(
                  'Instant Delivery',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Mobile Phone
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedChannel = 'phone'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedChannel == 'phone'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedChannel == 'phone'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_iphone_rounded,
                          size: 16,
                          color: _selectedChannel == 'phone'
                              ? const Color(0xFF173B67)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mobile Phone',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedChannel == 'phone'
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _selectedChannel == 'phone'
                                ? const Color(0xFF173B67)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Email Address
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedChannel = 'email'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedChannel == 'email'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedChannel == 'email'
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 16,
                          color: _selectedChannel == 'email'
                              ? const Color(0xFF173B67)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedChannel == 'email'
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _selectedChannel == 'email'
                                ? const Color(0xFF173B67)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Input Field
  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedChannel == 'phone'
              ? 'Registered Mobile Number'
              : 'Registered Email Address',
          style: const TextStyle(
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
          child: Row(
            children: [
              if (_selectedChannel == 'phone') ...[
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'IN  +91',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Palette.neutral,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 22,
                  color: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 10),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
              Expanded(
                child: TextField(
                  controller: _inputController,
                  keyboardType: _selectedChannel == 'phone'
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Palette.neutral,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedChannel == 'phone'
                        ? '98765 43210'
                        : 'sameer.verma@example.com',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.sms_outlined,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 14,
            ),
            SizedBox(width: 4),
            Text(
              'Enter your registered contact to set a new password',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 6. 15-Minute Expiration Notice Card
  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: Color(0xFF0284C7),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'For your ride safety & wallet security, reset authorization links automatically expire in 15 minutes.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Send Reset Link Button
  Widget _buildSendButton() {
    return InkWell(
      onTap: _isLoading ? null : _onSendResetLink,
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
                      'Proceed to Set Password',
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

  // 8. Back to Login Link
  Widget _buildBackToLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Remember your password? ',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Back to Login >',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFFF6B00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // 9. Help Desk Card
  Widget _buildHelpCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.headset_mic_rounded,
                color: Color(0xFF173B67),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lost access to phone?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173B67),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Reach Saffar 24×7 Driver & Rider desk',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.pushNamed(context, UserSupportScreen.routeName);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Help',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF173B67),
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.north_east_rounded,
                    size: 13,
                    color: Color(0xFF173B67),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
