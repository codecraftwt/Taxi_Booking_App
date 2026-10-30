// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
// import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
// import 'package:saffar_app/wrapper.dart';

// import '../../../../core/constants/nums.dart';
// import '../../../../core/palette.dart';
// import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

// class SignUpScreen extends StatefulWidget {
//   const SignUpScreen({Key? key}) : super(key: key);

//   static const String routeName = '/sign_up';

//   @override
//   State<SignUpScreen> createState() => _SignUpScreenState();
// }

// class _SignUpScreenState extends State<SignUpScreen> {
//   late final AuthCubit _authCubit;

//   late final TextEditingController _nameController;
//   late final TextEditingController _phoneController;
//   late final TextEditingController _passwordController;
//   late final TextEditingController _confirmPasswordController;

//   late final GlobalKey<FormState> _formKey;

//   late final List<FocusNode> _focusNodes;

//   bool _passwordVisible = false;
//   bool _confirmPasswordVisible = false;

//   /// Switches password visibility from true to false
//   /// and vice versa and [setState]'s it.
//   void _switchPasswordVisibility() {
//     setState(() {
//       _passwordVisible = !_passwordVisible;
//     });
//   }

//   /// Switches confirm password visibility from true to false
//   /// and vice versa and [setState]'s it.
//   void _switchConfirmPasswordVisibility() {
//     setState(() {
//       _confirmPasswordVisible = !_confirmPasswordVisible;
//     });
//   }

//   /// Unfocuses the keyboard, validates the form
//   /// then sign up function in called.
//   void _onSignUpButtonPressed() {
//     FocusScope.of(context).unfocus();

//     if (_formKey.currentState != null && _formKey.currentState!.validate()) {
//       final String name = _nameController.text;
//       final String phone = _phoneController.text;
//       final String password = _passwordController.text;

//       _authCubit.signUpGetUserAndTokenAndEmitThem(
//         context,
//         name,
//         phone,
//         password,
//       );
//     }
//   }

//   @override
//   void initState() {
//     super.initState();

//     _authCubit = context.read<AuthCubit>();

//     _nameController = TextEditingController();
//     _phoneController = TextEditingController();
//     _passwordController = TextEditingController();
//     _confirmPasswordController = TextEditingController();

//     _formKey = GlobalKey<FormState>();

//     _focusNodes = List.generate(4, (index) => FocusNode());
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();

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
//                 keyboardDismissBehavior:
//                     ScrollViewKeyboardDismissBehavior.onDrag,
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

//                           // Name text form field
//                           TextFormField(
//                             controller: _nameController,
//                             validator: (name) {
//                               return _authCubit.validateName(name);
//                             },
//                             autofocus: true,
//                             keyboardType: TextInputType.name,
//                             focusNode: _focusNodes[0],
//                             onEditingComplete: () {
//                               _focusNodes[0].unfocus();
//                               _focusNodes[1].requestFocus();
//                             },
//                             decoration: InputDecoration(
//                               hintText: 'Enter Name',
//                               border:
//                                   Theme.of(context).inputDecorationTheme.border,
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

//                           // Phone text form field
//                           TextFormField(
//                             controller: _phoneController,
//                             validator: (phone) {
//                               return _authCubit.validatePhone(phone);
//                             },
//                             keyboardType: TextInputType.phone,
//                             focusNode: _focusNodes[1],
//                             onEditingComplete: () {
//                               _focusNodes[1].unfocus();
//                               _focusNodes[2].requestFocus();
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
//                                     color:
//                                         Theme.of(context).colorScheme.outline,
//                                   ),
//                                 ),
//                               ),
//                               hintText: 'Enter Phone',
//                               border:
//                                   Theme.of(context).inputDecorationTheme.border,
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
//                             focusNode: _focusNodes[2],
//                             onEditingComplete: () {
//                               _focusNodes[2].unfocus();
//                               _focusNodes[3].requestFocus();
//                             },
//                             decoration: InputDecoration(
//                               hintText: 'Enter Password',
//                               border:
//                                   Theme.of(context).inputDecorationTheme.border,
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
//                           const SizedBox(height: 16),

//                           // Confirm password text form field
//                           TextFormField(
//                             controller: _confirmPasswordController,
//                             validator: (confirmPassword) {
//                               final String password = _passwordController.text;

//                               return _authCubit.validateConfirmPassword(
//                                 password,
//                                 confirmPassword,
//                               );
//                             },
//                             keyboardType: TextInputType.visiblePassword,
//                             obscureText: !_confirmPasswordVisible,
//                             focusNode: _focusNodes[3],
//                             onEditingComplete: () {
//                               _focusNodes[3].unfocus();
//                             },
//                             decoration: InputDecoration(
//                               hintText: 'Confirm Password',
//                               border:
//                                   Theme.of(context).inputDecorationTheme.border,
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
//                                   _switchConfirmPasswordVisibility();
//                                 },
//                                 child: !_confirmPasswordVisible
//                                     ? const Icon(Icons.visibility)
//                                     : const Icon(Icons.visibility_off),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 32),

//                           // Sign up button
//                           ElevatedButton(
//                             onPressed: state.loading
//                                 ? null
//                                 : () {
//                                     _onSignUpButtonPressed();
//                                   },
//                             style: ElevatedButton.styleFrom(
//                               textStyle: Theme.of(context)
//                                   .textTheme
//                                   .bodyLarge
//                                   ?.copyWith(fontWeight: FontWeight.bold),
//                               padding: const EdgeInsets.symmetric(vertical: 18),
//                             ),
//                             child: const Center(
//                               child: Text(
//                                 'Sign Up',
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),

//                           // Or
//                           const Text('Or'),

//                           // Sign in button
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
//                             child: const Center(child: Text('Sign In')),
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

import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/cubits/auth_cubit.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/wrapper.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  static const String routeName = '/sign_up';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final AuthCubit _authCubit;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final GlobalKey<FormState> _formKey;
  late final List<FocusNode> _focusNodes;

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  static const Color _background = Color(0xFFFFFAF6);
  static const Color _text = Color(0xFF202124);
  static const Color _muted = Color(0xFF777777);

  @override
  void initState() {
    super.initState();

    _authCubit = context.read<AuthCubit>();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _formKey = GlobalKey<FormState>();
    _focusNodes = List.generate(4, (_) => FocusNode());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _onSignUpButtonPressed() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      _authCubit.signUpGetUserAndTokenAndEmitThem(
        context,
        _nameController.text.trim(),
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

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    Widget? prefix,
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEAE5E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEAE5E0)),
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

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
    );
  }

  Widget _passwordToggle({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: visible ? 'Hide password' : 'Show password',
      icon: Icon(
        visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: _muted,
        size: 21,
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
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 24,
                        ),
                        child: IntrinsicHeight(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          color: _text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Branding
                                Center(
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: Palette.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(23),
                                    ),
                                    child: Icon(
                                      Icons.local_taxi_rounded,
                                      size: 43,
                                      color: Palette.primary,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 9),

                                Text(
                                  'Saffar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 35,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 0.8,
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
                                    color: _muted,
                                  ),
                                ),

                                const SizedBox(height: 27),

                                const Text(
                                  'Create your account',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: _text,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'Join Saffar and make every journey easier.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: _muted,
                                  ),
                                ),

                                const SizedBox(height: 25),

                                _fieldLabel('Full Name'),
                                TextFormField(
                                  controller: _nameController,
                                  focusNode: _focusNodes[0],
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  validator: _authCubit.validateName,
                                  onFieldSubmitted: (_) {
                                    _focusNodes[1].requestFocus();
                                  },
                                  decoration: _decoration(
                                    hint: 'Enter your full name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),

                                const SizedBox(height: 17),

                                _fieldLabel('Phone Number'),
                                TextFormField(
                                  controller: _phoneController,
                                  focusNode: _focusNodes[1],
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  validator: _authCubit.validatePhone,
                                  onFieldSubmitted: (_) {
                                    _focusNodes[2].requestFocus();
                                  },
                                  decoration: _decoration(
                                    hint: 'Enter your phone number',
                                    icon: Icons.phone_android_rounded,
                                    prefix: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Center(
                                        widthFactor: 1,
                                        child: Text(
                                          '+91',
                                          style: TextStyle(
                                            color: Palette.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 17),

                                _fieldLabel('Password'),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _focusNodes[2],
                                  obscureText: !_passwordVisible,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.next,
                                  validator: _authCubit.validatePassword,
                                  onFieldSubmitted: (_) {
                                    _focusNodes[3].requestFocus();
                                  },
                                  decoration: _decoration(
                                    hint: 'Create a password',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: _passwordToggle(
                                      visible: _passwordVisible,
                                      onPressed: () {
                                        setState(() {
                                          _passwordVisible =
                                              !_passwordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 17),

                                _fieldLabel('Confirm Password'),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  focusNode: _focusNodes[3],
                                  obscureText: !_confirmPasswordVisible,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) {
                                    return _authCubit.validateConfirmPassword(
                                      _passwordController.text,
                                      value,
                                    );
                                  },
                                  onFieldSubmitted: (_) {
                                    if (!state.loading) {
                                      _onSignUpButtonPressed();
                                    }
                                  },
                                  decoration: _decoration(
                                    hint: 'Re-enter your password',
                                    icon: Icons.verified_user_outlined,
                                    suffix: _passwordToggle(
                                      visible: _confirmPasswordVisible,
                                      onPressed: () {
                                        setState(() {
                                          _confirmPasswordVisible =
                                              !_confirmPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 26),

                                SizedBox(
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: state.loading
                                        ? null
                                        : _onSignUpButtonPressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Palette.primary.withValues(
                                        alpha: 0.55,
                                      ),
                                      elevation: 2,
                                      shadowColor: Palette.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: state.loading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Create Account',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              SizedBox(width: 9),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                const Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE9E2DC),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 13),
                                      child: Text(
                                        'ALREADY A MEMBER?',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                          color: _muted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE9E2DC),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 9),

                                TextButton(
                                  onPressed: state.loading
                                      ? null
                                      : () {
                                          _authCubit.toggleAuthScreen();
                                        },
                                  child: Text(
                                    'Sign In to Your Account',
                                    style: TextStyle(
                                      color: Palette.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Center(
                                  child: TextButton.icon(
                                    onPressed:
                                        state.loading ? null : _goBack,
                                    icon: Icon(
                                      Icons.local_taxi_rounded,
                                      size: 19,
                                      color: Palette.primary,
                                    ),
                                    label: Text(
                                      'Are you a driver? Switch mode',
                                      style: TextStyle(
                                        color: Palette.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                const Spacer(),

                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Center(
                                    child: Text(
                                      'FAST  •  RELIABLE  •  SAFE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFFAAAAAA),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
