import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/wrapper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  static const String routeName = '/sign_up';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final AuthCubit _authCubit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _passwordVisible = false;
  bool _termsAccepted = true;
  bool _isReferralExpanded = false;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _authCubit = context.read<AuthCubit>();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.dispose();
    _referralController.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final text = _passwordController.text;
    int strength = 0;
    if (text.isNotEmpty) {
      if (text.length >= 4) strength = 1;
      if (text.length >= 8) strength = 2;
      if (text.length >= 8 && RegExp(r'[0-9]').hasMatch(text)) strength = 3;
      if (text.length >= 8 &&
          RegExp(r'[0-9]').hasMatch(text) &&
          RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(text)) {
        strength = 4;
      }
    }
    if (_passwordStrength != strength) {
      setState(() {
        _passwordStrength = strength;
      });
    }
  }

  void _switchPasswordVisibility() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  void _onSignUpButtonPressed() {
    FocusScope.of(context).unfocus();

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms of Service to continue.'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final emailText = _emailController.text.trim();
      _authCubit.signUpGetUserAndTokenAndEmitThem(
        context,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _passwordController.text,
        email: emailText.isNotEmpty ? emailText : null,
      );
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _authCubit.toggleAuthScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listener: (context, userState) {
        if (userState.isLoggedIn && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            HomeScreen.routeName,
            (route) => false,
          );
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Bar: Back, Brand Icon + Create Account, Avatar
                    _buildTopBar(context),

                    const SizedBox(height: 14),

                    // 2. Badges: Personal Rider Account & SSL Secured
                    _buildBadgesRow(),

                    const SizedBox(height: 16),

                    // 3. Title & Subtitle
                    _buildHeadline(),

                    const SizedBox(height: 14),

                    // 4. Value Props: Instant Pickup, Zero Surge, 24x7 Safety
                    _buildValuePropsRow(),

                    const SizedBox(height: 18),

                    // 5. Input Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name
                          _buildFieldLabel('Full Name', isRequired: true),
                          const SizedBox(height: 7),
                          _buildNameField(),

                          const SizedBox(height: 16),

                          // Mobile Phone Number
                          _buildFieldLabel(
                            'Mobile Phone Number',
                            isRequired: true,
                            trailing: 'Primary Login ID',
                          ),
                          const SizedBox(height: 7),
                          _buildPhoneField(),
                          const SizedBox(height: 6),
                          _buildPhoneHelperText(),

                          const SizedBox(height: 14),

                          // Email Address (Optional)
                          _buildFieldLabel(
                            'Email Address',
                            trailingBadge: 'Optional',
                          ),
                          const SizedBox(height: 7),
                          _buildEmailField(),

                          const SizedBox(height: 16),

                          // Create Password
                          _buildFieldLabel(
                            'Create Password',
                            isRequired: true,
                            trailing: 'Min. 8 characters',
                          ),
                          const SizedBox(height: 7),
                          _buildPasswordField(),
                          const SizedBox(height: 8),
                          _buildPasswordStrengthBar(),

                          const SizedBox(height: 14),

                          // Promo / Referral Code Card
                          _buildReferralCard(),

                          const SizedBox(height: 14),

                          // Terms and Conditions Checkbox
                          _buildTermsCheckbox(),

                          const SizedBox(height: 18),

                          // Primary Create Account Button
                          _buildSignUpButton(state.loading),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Already have an account? Sign In ->
                    _buildSignInFooter(),

                    const SizedBox(height: 14),

                    // Security Footnote
                    _buildSecurityFootnote(),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 1. Top Bar
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _goBack,
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

        // Brand Icon & Screen Title
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
              'Create Account',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B67),
              ),
            ),
          ],
        ),

        // Right Profile Circle
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

  // 2. Badges Row
  Widget _buildBadgesRow() {
    return Row(
      children: [
        // Personal Rider Account
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
                Icons.electric_rickshaw_rounded,
                size: 14,
                color: Color(0xFF173B67),
              ),
              SizedBox(width: 5),
              Text(
                'PERSONAL RIDER ACCOUNT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173B67),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        // SSL Secured
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 13,
                color: Color(0xFF059669),
              ),
              SizedBox(width: 4),
              Text(
                'SSL Secured',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Headline
  Widget _buildHeadline() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Your Account',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Color(0xFF173B67),
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Join Saffar for fast, reliable city rides and transparent fares.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // 4. Value Props Row
  Widget _buildValuePropsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _propItem(Icons.bolt_rounded, 'Instant Pickup'),
          Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
          _propItem(Icons.payments_outlined, 'Zero Surge Caps'),
          Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
          _propItem(Icons.shield_outlined, '24x7 Safety'),
        ],
      ),
    );
  }

  Widget _propItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEDD5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 14),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF173B67),
          ),
        ),
      ],
    );
  }

  // Field Label with optional asterisks and trailing elements
  Widget _buildFieldLabel(
    String label, {
    bool isRequired = false,
    String? trailing,
    String? trailingBadge,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF173B67),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFFF6B00),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        if (trailingBadge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailingBadge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  // Full Name Field
  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: _nameController,
        focusNode: _nameFocus,
        textInputAction: TextInputAction.next,
        validator: _authCubit.validateName,
        onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Palette.neutral,
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.badge_outlined,
            size: 20,
            color: Color(0xFF64748B),
          ),
          hintText: 'e.g. Sameer Verma',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Phone Field
  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 17,
                  color: Color(0xFF173B67),
                ),
                SizedBox(width: 5),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
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
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _authCubit.validatePhone,
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Palette.neutral,
              ),
              decoration: const InputDecoration(
                hintText: '98765 43210',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildPhoneHelperText() {
    return const Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF10B981),
          size: 14,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'Account is directly secured via phone & permanent password.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Email Field
  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Palette.neutral,
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
          hintText: 'sameer.verma@example.com',
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Password Field
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        obscureText: !_passwordVisible,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        validator: _authCubit.validatePassword,
        onFieldSubmitted: (_) => _onSignUpButtonPressed(),
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
          hintText: 'Set a robust password',
          hintStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
          suffixIcon: IconButton(
            onPressed: _switchPasswordVisibility,
            icon: Icon(
              _passwordVisible
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
    );
  }

  // 4-Bar Password Strength Indicator
  Widget _buildPasswordStrengthBar() {
    Color getBarColor(int index) {
      if (_passwordStrength <= index) return const Color(0xFFE2E8F0);
      switch (_passwordStrength) {
        case 1:
          return const Color(0xFFEF4444);
        case 2:
          return const Color(0xFFF59E0B);
        case 3:
          return const Color(0xFF3B82F6);
        case 4:
          return const Color(0xFF10B981);
        default:
          return const Color(0xFFE2E8F0);
      }
    }

    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: getBarColor(index),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // Referral / Promo Code Card
  Widget _buildReferralCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isReferralExpanded = !_isReferralExpanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFFFF6B00),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Have a referral or promo code?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF173B67),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isReferralExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isReferralExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _referralController,
                      decoration: const InputDecoration(
                        hintText: 'Enter referral or promo code',
                        hintStyle: TextStyle(fontSize: 13),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_referralController.text.trim().isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Code "${_referralController.text.trim()}" applied!',
                            ),
                            backgroundColor: const Color(0xFF20A46B),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Terms Checkbox
  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _termsAccepted,
            activeColor: const Color(0xFFFF6B00),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (val) {
              setState(() => _termsAccepted = val ?? false);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.35,
              ),
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Saffar Terms of Service',
                  style: TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Primary Create Account Button
  Widget _buildSignUpButton(bool loading) {
    return InkWell(
      onTap: loading ? null : _onSignUpButtonPressed,
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
          child: loading
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
                      'Create Account & Continue',
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

  // Already have an account? Sign In ->
  Widget _buildSignInFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        GestureDetector(
          onTap: () {
            _authCubit.toggleAuthScreen();
          },
          child: const Text(
            'Sign In ->',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF6B00),
            ),
          ),
        ),
      ],
    );
  }

  // Security Footnote
  Widget _buildSecurityFootnote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: Color(0xFF10B981),
        ),
        SizedBox(width: 4),
        Text(
          'End-to-End Encrypted',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8),
        Text(
          '•',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        SizedBox(width: 8),
        Icon(
          Icons.bolt_rounded,
          size: 14,
          color: Color(0xFF0284C7),
        ),
        SizedBox(width: 2),
        Text(
          'No OTP Delay',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
