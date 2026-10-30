// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
// import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
// import 'package:saffar_app/wrapper.dart';

// import '../../../../core/constants/nums.dart';
// import '../../../../core/palette.dart';
// import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

// class SignInScreen extends StatefulWidget {
//   const SignInScreen({Key? key}) : super(key: key);

//   static const String routeName = '/sign_in';

//   @override
//   State<SignInScreen> createState() => _SignInScreenState();
// }

// class _SignInScreenState extends State<SignInScreen> {
//   late final AuthCubit _authCubit;

//   late final TextEditingController _phoneController;
//   late final TextEditingController _passwordController;

//   late final GlobalKey<FormState> _formKey;

//   late final List<FocusNode> _focusNodes;

//   bool _passwordVisible = false;

//   /// Switches password visibility from true to false
//   /// and vice versa and [setState]'s it.
//   void _switchPasswordVisibility() {
//     setState(() {
//       _passwordVisible = !_passwordVisible;
//     });
//   }

//   /// Unfocuses the keyboard, validates the form
//   /// then sign in function in called.
//   void _onSignInButtonPressed() {
//     FocusScope.of(context).unfocus();

//     if (_formKey.currentState != null && _formKey.currentState!.validate()) {
//       final String phone = _phoneController.text;
//       final String password = _passwordController.text;

//       _authCubit.signInGetUserAndTokenAndEmitThem(context, phone, password);
//     }
//   }

//   @override
//   void initState() {
//     super.initState();

//     _authCubit = context.read<AuthCubit>();

//     _phoneController = TextEditingController();
//     _passwordController = TextEditingController();

//     _formKey = GlobalKey<FormState>();

//     _focusNodes = List.generate(2, (index) => FocusNode());
//   }

//   @override
//   void dispose() {
//     _phoneController.dispose();
//     _passwordController.dispose();

//     for (final focusNode in _focusNodes) {
//       focusNode.dispose();
//     }

//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<UserCubit, UserState>(
//       listener: (context, userState) {
//         if (userState.isLoggedIn && mounted) {
//           Navigator.pushNamedAndRemoveUntil(
//             context,
//             Wrapper.routeName,
//             (route) => false,
//           );
//         }
//       },
//       child: BlocBuilder<AuthCubit, AuthState>(
//         builder: (context, state) {
//           return WillPopScope(
//             onWillPop: () async {
//               if (state.loading) return false;
//               Navigator.pushReplacementNamed(
//                 context,
//                 RoleSelectionScreen.routeName,
//               );
//               return false;
//             },
//             child: Scaffold(
//               appBar: AppBar(
//                 backgroundColor: Colors.transparent,
//                 elevation: 0,
//                 leading: IconButton(
//                   icon: const Icon(Icons.arrow_back, color: Colors.black87),
//                   onPressed: () {
//                     Navigator.pushReplacementNamed(
//                       context,
//                       RoleSelectionScreen.routeName,
//                     );
//                   },
//                 ),
//               ),
//               body: SingleChildScrollView(
//                 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: Nums.horizontalPadding),
//                   child: SizedBox(
//                     height: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
//                     child: Form(
//                       key: _formKey,
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         mainAxisSize: MainAxisSize.max,
//                         children: [
//                           const Text(
//                             'Saffar',
//                             style: TextStyle(
//                               fontSize: 48,
//                               color: Palette.primary,
//                               fontWeight: FontWeight.bold,
//                               fontStyle: FontStyle.italic,
//                             ),
//                           ),
//                           const SizedBox(height: 32),

//                           // Phone text form field
//                           TextFormField(
//                             autofocus: true,
//                             controller: _phoneController,
//                             validator: (phone) {
//                               return _authCubit.validatePhone(phone);
//                             },
//                             keyboardType: TextInputType.phone,
//                             focusNode: _focusNodes[0],
//                             onEditingComplete: () {
//                               _focusNodes[0].unfocus();
//                               _focusNodes[1].requestFocus();
//                             },
//                             decoration: InputDecoration(
//                               prefixIcon: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 12,
//                                   vertical: 12,
//                                 ),
//                                 child: Text(
//                                   '+91',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     color: Theme.of(context).colorScheme.outline,
//                                   ),
//                                 ),
//                               ),
//                               hintText: 'Enter Phone',
//                               border: Theme.of(context).inputDecorationTheme.border,
//                               enabledBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .enabledBorder,
//                               focusedBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .focusedBorder,
//                               errorBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .errorBorder,
//                             ),
//                           ),
//                           const SizedBox(height: 16),

//                           // Password text form field
//                           TextFormField(
//                             controller: _passwordController,
//                             validator: (password) {
//                               return _authCubit.validatePassword(password);
//                             },
//                             keyboardType: TextInputType.visiblePassword,
//                             obscureText: !_passwordVisible,
//                             focusNode: _focusNodes[1],
//                             onEditingComplete: () {
//                               _focusNodes[1].unfocus();
//                             },
//                             decoration: InputDecoration(
//                               hintText: 'Enter Password',
//                               border: Theme.of(context).inputDecorationTheme.border,
//                               enabledBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .enabledBorder,
//                               focusedBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .focusedBorder,
//                               errorBorder: Theme.of(context)
//                                   .inputDecorationTheme
//                                   .errorBorder,
//                               suffixIcon: InkWell(
//                                 onTap: () {
//                                   _switchPasswordVisibility();
//                                 },
//                                 child: !_passwordVisible
//                                     ? const Icon(Icons.visibility)
//                                     : const Icon(Icons.visibility_off),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 32),

//                           // Sign in button
//                           ElevatedButton(
//                             onPressed: state.loading
//                                 ? null
//                                 : () {
//                                     _onSignInButtonPressed();
//                                   },
//                             style: ElevatedButton.styleFrom(
//                               textStyle: Theme.of(context)
//                                   .textTheme
//                                   .bodyLarge
//                                   ?.copyWith(fontWeight: FontWeight.bold),
//                               padding: const EdgeInsets.symmetric(vertical: 18),
//                             ),
//                             child: Center(
//                               child: Text(
//                                 state.loading ? '...' : 'Sign In',
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),

//                           // Or
//                           const Text('Or'),

//                           // Sign up button
//                           TextButton(
//                             onPressed: state.loading
//                                 ? null
//                                 : () {
//                                     _authCubit.toggleAuthScreen();
//                                   },
//                             style: TextButton.styleFrom(
//                               textStyle: Theme.of(context)
//                                   .textTheme
//                                   .bodyLarge
//                                   ?.copyWith(fontWeight: FontWeight.bold),
//                               padding: const EdgeInsets.symmetric(vertical: 18),
//                             ),
//                             child: const Center(child: Text('Sign Up')),
//                           ),

//                           const SizedBox(height: 8),

//                           // Switch to Driver Mode
//                           TextButton.icon(
//                             onPressed: () {
//                               Navigator.pushReplacementNamed(
//                                 context,
//                                 RoleSelectionScreen.routeName,
//                               );
//                             },
//                             icon: const Icon(Icons.drive_eta, size: 20),
//                             label: const Text('Are you a Driver? Switch Mode'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/wrapper.dart';

import '../../../../core/constants/nums.dart';
import '../../../../core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  static const String routeName = '/sign_in';

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AuthCubit _authCubit;

  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _passwordVisible = false;

  static const Color _background = Color(0xFFFFFAF6);
  static const Color _textColor = Color(0xFF252525);
  static const Color _mutedColor = Color(0xFF777777);
  static const Color _borderColor = Color(0xFFEAE5E0);

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
    Navigator.pushReplacementNamed(
      context,
      RoleSelectionScreen.routeName,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFFAAAAAA),
      ),
      prefixIcon: Icon(
        icon,
        color: Palette.primary,
        size: 21,
      ),
      prefix: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Palette.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: Palette.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(
            Icons.local_taxi_rounded,
            size: 50,
            color: Palette.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Saffar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 43,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
            color: Palette.primary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'YOUR JOURNEY, OUR PRIORITY',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: _mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      autofocus: false,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: _authCubit.validatePhone,
      onFieldSubmitted: (_) {
        _passwordFocus.requestFocus();
      },
      decoration: _inputDecoration(
        hint: 'Enter your phone number',
        icon: Icons.phone_android_rounded,
        prefix: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              '+91',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Palette.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: !_passwordVisible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      validator: _authCubit.validatePassword,
      onFieldSubmitted: (_) {
        _onSignInButtonPressed();
      },
      decoration: _inputDecoration(
        hint: 'Enter your password',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          tooltip: _passwordVisible
              ? 'Hide password'
              : 'Show password',
          onPressed: _switchPasswordVisibility,
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: _mutedColor,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool loading) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: loading ? null : _onSignInButtonPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Palette.primary.withValues(alpha: 0.55),
          elevation: 2,
          shadowColor: Palette.primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listener: (context, userState) {
        if (userState.isLoggedIn && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            Wrapper.routeName,
            (route) => false,
          );
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && !state.loading) {
                _goBack();
              }
            },
            child: Scaffold(
              backgroundColor: _background,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(
                        horizontal: Nums.horizontalPadding,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: state.loading ? null : _goBack,
                                child: const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: _textColor,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          _buildBrand(),

                          const SizedBox(height: 32),

                          const Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: _textColor,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Sign in to continue your journey with Saffar.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: _mutedColor,
                            ),
                          ),

                          const SizedBox(height: 25),

                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLabel('Phone Number'),
                                _buildPhoneField(),

                                const SizedBox(height: 18),

                                _buildLabel('Password'),
                                _buildPasswordField(),

                                const SizedBox(height: 26),

                                _buildSignInButton(state.loading),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: _borderColor,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  'NEW TO SAFFAR?',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: _mutedColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: _borderColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: state.loading
                                ? null
                                : () {
                                    _authCubit.toggleAuthScreen();
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Palette.primary,
                              minimumSize: const Size.fromHeight(51),
                              side: BorderSide(
                                color: Palette.primary.withValues(
                                  alpha: 0.40,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              'Create an Account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton.icon(
                            onPressed:
                                state.loading ? null : _goBack,
                            icon: Icon(
                              Icons.local_taxi_rounded,
                              size: 20,
                              color: Palette.primary,
                            ),
                            label: Text(
                              'Are you a driver? Switch mode',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Palette.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'FAST  •  RELIABLE  •  SAFE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFFAAAAAA),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
