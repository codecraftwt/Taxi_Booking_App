import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/auth_wrapper.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/splash/presenter/cubits/splash_cubit.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  static const String routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentSlide = 0;
  Timer? _autoSlideTimer;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Safe & Verified Journeys',
      'desc':
          '4-digit OTP ride verification, 24/7 emergency dispatch, and top-rated professional partners.',
    },
    {
      'title': 'Transparent Lowest Fares',
      'desc':
          'Zero surge hidden fees, flat upfront pricing for Auto, Bike, and Cab across all city routes.',
    },
    {
      'title': 'Green & Electric Commutes',
      'desc':
          'Smart EV auto-rickshaws saving 3.8 kg CO₂ on every trip with zero noise pollution.',
    },
  ];

  @override
  void initState() {
    super.initState();
    context.read<SplashCubit>().init(context);

    // Auto-advance slides every 3.5 seconds
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentSlide + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onSignInWithPhone(BuildContext context) {
    Navigator.pushNamed(
      context,
      AuthWrapper.routeName,
      arguments: {'initialSignIn': true},
    );
  }

  void _onCreateAccount(BuildContext context) {
    Navigator.pushNamed(
      context,
      AuthWrapper.routeName,
      arguments: {'initialSignIn': false},
    );
  }

  void _onSwitchToDriverMode(BuildContext context) {
    final driverState = context.read<DriverCubit>().state;
    if (driverState.isLoggedIn) {
      Navigator.pushReplacementNamed(context, DriverShellScreen.routeName);
    } else {
      Navigator.pushNamed(context, DriverSignInScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      listener: (context, state) {
        if (state is SplashDone) {
          final driverState = context.read<DriverCubit>().state;
          final userState = context.read<UserCubit>().state;

          if (driverState.isLoggedIn) {
            Timer(const Duration(milliseconds: 600), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, DriverShellScreen.routeName);
              }
            });
          } else if (userState.isLoggedIn) {
            // Passenger logged in: transition smoothly to Home
            Timer(const Duration(milliseconds: 600), () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, HomeScreen.routeName);
              }
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Top Bar: GPS Active pill & Driver Mode button
                        _buildTopStatusBar(context),

                        const SizedBox(height: 16),

                        // 2. Brand Icon Squircle & Saffar Title
                        _buildBrandHeader(),

                        const SizedBox(height: 16),

                        // 3. Showcase Feature Card with Carousel
                        _buildShowcaseCard(),

                        const SizedBox(height: 14),

                        // 4. "Partner with Saffar" Driver Banner
                        _buildDriverBanner(context),

                        const SizedBox(height: 14),

                        // 5. "Sign In with Phone" Primary Button
                        _buildSignInButton(context),

                        const SizedBox(height: 12),

                        // 6. "New to Saffar? Create an account" Secondary Link
                        _buildCreateAccountLink(context),

                        const Spacer(),
                        const SizedBox(height: 10),

                        // 7. Terms of Service & Privacy Policy Footer
                        _buildLegalFooter(context),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 1. Top Status Bar: GPS & Driver Mode Pill
  Widget _buildTopStatusBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // GPS Active Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'GPS Active • Urban Hub',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),

        // Driver Mode Switcher Pill
        InkWell(
          onTap: () => _onSwitchToDriverMode(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: Color(0xFF173B67),
                ),
                SizedBox(width: 4),
                Text(
                  'DRIVER MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173B67),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Brand Header: Squircle with Arrow & Thunderbolt
  Widget _buildBrandHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Saffar Official Brand Logo
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/images/saffar_logo_rounded.png',
                fit: BoxFit.contain,
              ),
            ),

            // Verified Badge
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Saffar Title
        const Text(
          'Saffar',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Palette.neutral,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle
        const Text(
          'Fast, Safe & Affordable Rides',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // 3. Feature Showcase Card with floating chips & carousel
  Widget _buildShowcaseCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Image with floating chips
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                // Illustration / Highway image
                Container(
                  height: 165,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                  ),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=600',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFFFF6B00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          size: 64,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),

                // Dusk gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0F172A).withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Vehicle Chips: Bike, Auto, Cab
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      _vehicleChip(Icons.two_wheeler_rounded, 'Bike'),
                      const SizedBox(width: 6),
                      _vehicleChip(Icons.electric_rickshaw_rounded, 'Auto'),
                      const SizedBox(width: 6),
                      _vehicleChip(Icons.local_taxi_rounded, 'Cab'),
                    ],
                  ),
                ),

                // Insured Trips Badge
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 13,
                          color: Color(0xFF38BDF8),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Insured Trips',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Slide Text Content & Page Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                SizedBox(
                  height: 72,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) {
                      setState(() => _currentSlide = idx);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slide['title']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Palette.neutral,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            slide['desc']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final bool isActive = _currentSlide == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFF6B00)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFF6B00)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Palette.neutral,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Partner with Saffar: Driver Banner Card
  Widget _buildDriverBanner(BuildContext context) {
    return InkWell(
      onTap: () => _onSwitchToDriverMode(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Color(0xFF1E3A8A),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EARN ON YOUR SCHEDULE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Partner with Saffar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Palette.neutral,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Text(
                'Drive & Earn',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. "Sign In with Phone" Primary CTA Button
  Widget _buildSignInButton(BuildContext context) {
    return InkWell(
      onTap: () => _onSignInWithPhone(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B00),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.32),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_rounded, color: Colors.white, size: 19),
            SizedBox(width: 8),
            Text(
              'Sign In with Phone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. "New to Saffar? Create an account"
  Widget _buildCreateAccountLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'New to Saffar? ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        GestureDetector(
          onTap: () => _onCreateAccount(context),
          child: const Text(
            'Create an account',
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

  // 7. Terms of Service & Privacy Policy Footer
  Widget _buildLegalFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            height: 1.4,
          ),
          children: [
            TextSpan(text: "By proceeding, you agree to Saffar's "),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: ' & '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
