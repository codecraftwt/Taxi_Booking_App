import 'package:flutter/material.dart';
import 'package:saffar_app/features/authentication/presenter/auth_wrapper.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/payment/presenter/screens/payment_screen.dart';
import 'package:saffar_app/features/splash/presenter/screens/splash_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_profile_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_ride_history_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';
import 'package:saffar_app/features/view_map/presenter/screens/view_map_screen.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_up_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_dashboard_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_earnings_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trips_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_profile_screen.dart';
import 'package:saffar_app/wrapper.dart';

import '../features/authentication/presenter/screens/sign_in_screen.dart';
import '../features/authentication/presenter/screens/sign_up_screen.dart';

/// Handles routing in the app
class CustomRouter {
  /// Generates initial routes
  static List<Route<dynamic>> onGenerateInitialRoutes(String name) {
    return [
      MaterialPageRoute(
        builder: (_) => const SplashScreen(),
      ),
    ];
  }

  /// Generates routes for named navigation
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Wrapper.routeName:
        return MaterialPageRoute(
          builder: (_) => const Wrapper(),
        );
      case RoleSelectionScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        );
      case HomeScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case UserProfileScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const UserProfileScreen(),
        );
      case UserRideHistoryScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const UserRideHistoryScreen(),
        );
      case UserSupportScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const UserSupportScreen(),
        );
      case DriverSignInScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverSignInScreen(),
        );
      case DriverSignUpScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverSignUpScreen(),
        );
      case DriverShellScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverShellScreen(),
        );
      case DriverDashboardScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverShellScreen(),
        );
      case DriverEarningsScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverEarningsScreen(),
        );
      case DriverTripsScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverTripsScreen(),
        );
      case DriverProfileScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverProfileScreen(),
        );
      case PaymentScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentScreenArguments:
                settings.arguments as PaymentScreenArguments,
          ),
        );
      case ViewMapScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => ViewMapScreen(
            viewMapScreenArguments:
                settings.arguments as ViewMapScreenArguments,
          ),
        );
      case SplashScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      case AuthWrapper.routeName:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(initialSignIn: true),
        );
      case SignInScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(initialSignIn: true),
        );
      case SignUpScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(initialSignIn: false),
        );
      default:
        return MaterialPageRoute(
          builder: (_) {
            return Scaffold(
              body: Center(
                child: Text('No route with the name ${settings.name}'),
              ),
            );
          },
        );
    }
  }
}
