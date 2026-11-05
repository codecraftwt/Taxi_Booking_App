import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
import 'package:saffar_app/features/authentication/presenter/screens/reset_password_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/wrapper.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  static const String routeName = '/sign_in';

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AuthCubit _authCubit;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _authCubit = context.read<AuthCubit>();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchPasswordVisibility() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  void _onSignInButtonPressed() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      _authCubit.signInGetUserAndTokenAndEmitThem(
        context,
        _phoneController.text.trim(),
        _passwordController.text,
      );
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/splash');
    }
  }

  void _showForgotPasswordModal() {
    Navigator.pushNamed(
      context,
      ResetPasswordScreen.routeName,
      arguments: {'phone': _phoneController.text.trim()},
    );
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
                    // 1. Top Bar: Back Arrow, Brand Nav Icon + Sign In, Avatar Icon
                    _buildTopBar(context),

                    const SizedBox(height: 16),

                    // 2. Role Segmented Bar: Rider vs Driver Partner
                    _buildRoleSegment(context),

                    const SizedBox(height: 20),

                    // 3. SAFFAR MOBILITY Dot & Headline
                    _buildHeader(),

                    const SizedBox(height: 24),

                    // 4. Input Form: Phone + Password
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Phone Label & Field
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF173B67),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPhoneField(),

                          const SizedBox(height: 18),

                          // Password Label & Field
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF173B67),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPasswordField(),

                          const SizedBox(height: 10),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _showForgotPasswordModal,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF173B67),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // 5. Log In Button
                          _buildLogInButton(state.loading),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 6. Or continue with Divider
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 7. Social Logins: Google & Apple
                    _buildSocialButtons(context),

                    const SizedBox(height: 26),

                    // 8. Register Footer Link
                    _buildRegisterFooter(context),

                    const SizedBox(height: 16),
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
        // Back Button
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
              'Sign In',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B67),
              ),
            ),
          ],
        ),

        // Right Profile Avatar Circle
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

  // 2. Role Segment Toggle: Rider vs Driver Partner
  Widget _buildRoleSegment(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Rider (Active)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.electric_rickshaw_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Rider',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Driver Partner (Inactive)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushReplacementNamed(
                  context,
                  DriverSignInScreen.routeName,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF173B67),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Driver Partner',
                      style: TextStyle(
                        color: Color(0xFF173B67),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. SAFFAR MOBILITY Tag & Headline
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8500),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'SAFFAR MOBILITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B67),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF173B67),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Log in to book your daily commute across the city',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 4. Phone Input Field with Country Code
  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Country prefix
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

          // Text Field
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _authCubit.validatePhone,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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

  // 5. Password Input Field
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
        onFieldSubmitted: (_) => _onSignInButtonPressed(),
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
          hintText: 'Enter your password',
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

  // 6. Log In Button
  Widget _buildLogInButton(bool loading) {
    return InkWell(
      onTap: loading ? null : _onSignInButtonPressed,
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
                      'Log In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

  // 7. Social Buttons: Google & Apple
  Widget _buildSocialButtons(BuildContext context) {
    return Row(
      children: [
        // Google Button
        Expanded(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google Sign In coming soon!')),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Google',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Palette.neutral,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Apple Button
        Expanded(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apple Sign In coming soon!')),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apple,
                    color: Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Apple',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Palette.neutral,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 8. Register Footer
  Widget _buildRegisterFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
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
            'Register',
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
}
