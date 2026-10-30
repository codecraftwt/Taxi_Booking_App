// import 'package:flutter/material.dart';
// import 'package:saffar_app/core/constants/nums.dart';
// import 'package:saffar_app/core/palette.dart';
// import 'package:saffar_app/features/authentication/presenter/auth_wrapper.dart';
// import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';

// class RoleSelectionScreen extends StatelessWidget {
//   const RoleSelectionScreen({Key? key}) : super(key: key);

//   static const String routeName = '/role_selection';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: Nums.horizontalPadding, vertical: 24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const Spacer(),

//               // Brand Icon & Title
//               const Icon(
//                 Icons.local_taxi,
//                 size: 72,
//                 color: Palette.primary,
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Saffar',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 44,
//                   fontWeight: FontWeight.bold,
//                   fontStyle: FontStyle.italic,
//                   color: Palette.primary,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Your Smart City Taxi Booking Solution',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey.shade600,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),

//               const SizedBox(height: 48),

//               const Text(
//                 'How would you like to continue?',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.black87,
//                 ),
//               ),

//               const SizedBox(height: 24),

//               // Passenger Card
//               _buildRoleCard(
//                 context: context,
//                 title: 'Continue as Passenger',
//                 subtitle: 'Book a ride, track your driver live on the map, and travel easily.',
//                 icon: Icons.person_pin_circle_outlined,
//                 color: Palette.primary,
//                 onTap: () {
//                   Navigator.pushNamed(context, AuthWrapper.routeName);
//                 },
//               ),

//               const SizedBox(height: 16),

//               // Driver Card
//               _buildRoleCard(
//                 context: context,
//                 title: 'Continue as Driver',
//                 subtitle: 'Accept ride requests, manage vehicle status, and earn on every trip.',
//                 icon: Icons.drive_eta,
//                 color: Colors.teal.shade700,
//                 onTap: () {
//                   Navigator.pushNamed(context, DriverSignInScreen.routeName);
//                 },
//               ),

//               const Spacer(),

//               Text(
//                 'Fast • Reliable • Safe',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade400,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRoleCard({
//     required BuildContext context,
//     required String title,
//     required String subtitle,
//     required IconData icon,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
//           boxShadow: [
//             BoxShadow(
//               color: color.withValues(alpha: 0.08),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: color.withValues(alpha: 0.12),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(icon, color: color, size: 32),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: TextStyle(
//                       fontSize: 17,
//                       fontWeight: FontWeight.bold,
//                       color: color,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     subtitle,
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey.shade600,
//                       height: 1.3,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(Icons.arrow_forward_ios, size: 16, color: color),
//           ],
//         ),
//       ),
//     );
//   }
// }





import 'package:flutter/material.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/auth_wrapper.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const String routeName = '/role_selection';

  static const Color _background = Color(0xFFFFFBF7);
  static const Color _driverColor = Color(0xFF008577);
  static const Color _textColor = Color(0xFF252525);
  static const Color _mutedColor = Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Nums.horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      // Brand
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Palette.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            Icons.local_taxi_rounded,
                            size: 53,
                            color: Palette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        'Saffar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 43,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.1,
                          color: Palette.primary,
                        ),
                      ),
                      const SizedBox(height: 7),

                      const Text(
                        'YOUR JOURNEY, OUR PRIORITY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                          color: _mutedColor,
                        ),
                      ),

                      const SizedBox(height: 42),

                      const Text(
                        'Welcome to Saffar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'How would you like to continue?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedColor,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 27),

                      // Passenger
                      _RoleCard(
                        title: 'Continue as Passenger',
                        subtitle:
                            'Book rides, track your driver live, '
                            'and reach your destination with ease.',
                        icon: Icons.person_pin_circle_rounded,
                        color: Palette.primary,
                        tag: 'BOOK A RIDE',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AuthWrapper.routeName,
                          );
                        },
                      ),

                      const SizedBox(height: 17),

                      // Driver
                      _RoleCard(
                        title: 'Continue as Driver',
                        subtitle:
                            'Accept ride requests, manage your trips, '
                            'and grow your earnings.',
                        icon: Icons.directions_car_rounded,
                        color: _driverColor,
                        tag: 'START EARNING',
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            DriverSignInScreen.routeName,
                          );
                        },
                      ),

                      const Spacer(flex: 2),
                      const SizedBox(height: 30),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 15,
                            color: _driverColor,
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'Fast  •  Reliable  •  Safe',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _mutedColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tag,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.055),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 33,
                ),
              ),
              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),

                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),

              Icon(
                Icons.arrow_forward_rounded,
                size: 23,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
