import 'package:flutter/material.dart';
import 'package:saffar_app/features/authentication/presenter/auth_wrapper.dart';
import 'package:saffar_app/features/payment/presenter/screens/payment_screen.dart';
import 'package:saffar_app/features/splash/presenter/screens/splash_screen.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';

// User / Customer Screens
import 'package:saffar_app/features/user/home/presenter/screens/home.dart';
import 'package:saffar_app/features/user/ride/presenter/screens/active_trip_screen.dart';
import 'package:saffar_app/features/user/ride/presenter/screens/ride_confirmation_screen.dart';
import 'package:saffar_app/features/user/ride/presenter/screens/rate_review_driver_screen.dart';
import 'package:saffar_app/features/user/view_map/presenter/screens/view_map_screen.dart';
import 'package:saffar_app/features/user/profile/presenter/screens/user_profile_screen.dart';
import 'package:saffar_app/features/user/profile/presenter/screens/user_ride_history_screen.dart';
import 'package:saffar_app/features/user/profile/presenter/screens/user_support_screen.dart';

// Driver Screens
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_up_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_forgot_password_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_reset_password_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_dashboard_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_shell_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_earnings_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trips_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_details_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_profile_screen.dart';
import 'package:saffar_app/core/models/vehicle.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_vehicles_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/add_vehicle_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/vehicle_details_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/edit_vehicle_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/vehicle_document_upload_screen.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:saffar_app/features/driver/presenter/screens/ride_request_details_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_pickup_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_pickup_navigation_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/ride_otp_verification_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_active_trip_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_completed_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_cancel_ride_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_cancellation_success_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_earning_details_screen.dart';
import 'package:saffar_app/wrapper.dart';

import '../features/authentication/presenter/screens/sign_in_screen.dart';
import '../features/authentication/presenter/screens/sign_up_screen.dart';
import '../features/authentication/presenter/screens/forgot_password_screen.dart';
import '../features/authentication/presenter/screens/reset_password_screen.dart';

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
      case DriverForgotPasswordScreen.routeName:
        final forgotArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DriverForgotPasswordScreen(
            initialPhone: forgotArgs?['phone'] as String?,
          ),
        );
      case DriverResetPasswordScreen.routeName:
        final resetArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DriverResetPasswordScreen(
            phone: resetArgs?['phone'] as String? ?? '',
            resetToken: resetArgs?['resetToken'] as String?,
          ),
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
      case DriverTripDetailsScreen.routeName:
        final tripArgs = settings.arguments as Map<String, dynamic>? ?? {};
        final rideId = tripArgs['ride_id']?.toString() ?? '';
        return MaterialPageRoute(
          builder: (_) => DriverTripDetailsScreen(rideId: rideId),
        );
      case DriverProfileScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverProfileScreen(),
        );
      case DriverVehiclesScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const DriverVehiclesScreen(),
        );
      case AddVehicleScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => const AddVehicleScreen(),
        );
      case VehicleDetailsScreen.routeName:
        final vehicle = settings.arguments as Vehicle;
        return MaterialPageRoute(
          builder: (_) => VehicleDetailsScreen(vehicle: vehicle),
        );
      case EditVehicleScreen.routeName:
        final vehicle = settings.arguments as Vehicle;
        return MaterialPageRoute(
          builder: (_) => EditVehicleScreen(vehicle: vehicle),
        );
      case VehicleDocumentUploadScreen.routeName:
        final vehicle = settings.arguments as Vehicle;
        return MaterialPageRoute(
          builder: (_) => VehicleDocumentUploadScreen(vehicle: vehicle),
        );
      case RideRequestDetailsScreen.routeName:
        final request = settings.arguments as RideRequest;
        return MaterialPageRoute(
          builder: (_) => RideRequestDetailsScreen(request: request),
        );
      case DriverPickupNavigationScreen.routeName:
        final dynamic navRaw = settings.arguments;
        final String rideId = (navRaw is String)
            ? navRaw
            : (navRaw is Map ? navRaw['ride_id']?.toString() : null) ?? '';
        return MaterialPageRoute(
          builder: (_) => BlocProvider<DriverPickupCubit>(
            create: (_) => DriverPickupCubit(),
            child: DriverPickupNavigationScreen(rideId: rideId),
          ),
        );
      case RideOtpVerificationScreen.routeName:
        final dynamic otpRaw = settings.arguments;
        final Map<String, dynamic>? otpArgs = otpRaw is Map<String, dynamic> ? otpRaw : (otpRaw is Map ? Map<String, dynamic>.from(otpRaw) : null);
        final String rideId = (otpRaw is String)
            ? otpRaw
            : (otpArgs?['ride_id']?.toString() ?? '');
        final passengerName = otpArgs?['passenger_name']?.toString() ?? 'Passenger';
        final pickupAddress = otpArgs?['pickup_address']?.toString() ?? '';
        final fare = otpArgs?['fare']?.toString() ?? '';
        return MaterialPageRoute(
          builder: (_) => BlocProvider<DriverPickupCubit>(
            create: (_) => DriverPickupCubit(),
            child: RideOtpVerificationScreen(
              rideId: rideId,
              passengerName: passengerName,
              pickupAddress: pickupAddress,
              fare: fare,
            ),
          ),
        );
      case DriverActiveTripScreen.routeName:
        final dynamic activeRaw = settings.arguments;
        final String activeRideId = (activeRaw is String)
            ? activeRaw
            : (activeRaw is Map ? activeRaw['ride_id']?.toString() : null) ?? '';
        return MaterialPageRoute(
          builder: (_) => BlocProvider<DriverPickupCubit>(
            create: (_) => DriverPickupCubit(),
            child: DriverActiveTripScreen(rideId: activeRideId),
          ),
        );
      case DriverTripCompletedScreen.routeName:
        final completedArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => DriverTripCompletedScreen(
            rideId: completedArgs['ride_id']?.toString() ?? '',
            finalFare: (completedArgs['final_fare'] is num)
                ? (completedArgs['final_fare'] as num).toDouble()
                : (double.tryParse(completedArgs['final_fare']?.toString() ?? '0') ?? 0.0),
            distanceKm: (completedArgs['distance_km'] is num)
                ? (completedArgs['distance_km'] as num).toDouble()
                : (double.tryParse(completedArgs['distance_km']?.toString() ?? '0') ?? 0.0),
            durationMinutes: (completedArgs['duration_minutes'] is num)
                ? (completedArgs['duration_minutes'] as num).toInt()
                : (int.tryParse(completedArgs['duration_minutes']?.toString() ?? '0') ?? 0),
            passengerName: completedArgs['passenger_name']?.toString() ?? 'Passenger',
            pickupAddress: completedArgs['pickup_address']?.toString() ?? '',
            destinationAddress: completedArgs['destination_address']?.toString() ?? '',
            paymentMethod: completedArgs['payment_method']?.toString() ?? 'Paid',
          ),
        );
      case DriverCancelRideScreen.routeName:
        final cancelArgs = settings.arguments as Map<String, dynamic>? ?? {};
        final rideId = cancelArgs['ride_id']?.toString() ?? '';
        return MaterialPageRoute(
          builder: (_) => BlocProvider<DriverPickupCubit>(
            create: (_) => DriverPickupCubit(),
            child: DriverCancelRideScreen(
              rideId: rideId,
              passengerName: cancelArgs['passenger_name']?.toString() ?? 'Passenger',
              pickupAddress: cancelArgs['pickup_address']?.toString() ?? '',
              destinationAddress: cancelArgs['destination_address']?.toString() ?? '',
              fare: cancelArgs['fare']?.toString() ?? '₹135.00',
              currentStatus: cancelArgs['current_status']?.toString() ?? 'accepted',
            ),
          ),
        );
      case DriverCancellationSuccessScreen.routeName:
        final successArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => DriverCancellationSuccessScreen(
            rideId: successArgs['ride_id']?.toString() ?? '',
            reason: successArgs['reason']?.toString() ?? 'Cancelled',
            notes: successArgs['notes']?.toString(),
            passengerName: successArgs['passenger_name']?.toString() ?? 'Passenger',
            pickupAddress: successArgs['pickup_address']?.toString() ?? 'Pickup Point',
            cancelledAt: successArgs['cancelled_at']?.toString(),
          ),
        );
      case DriverTripEarningDetailsScreen.routeName:
        final earnArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => DriverTripEarningDetailsScreen(
            rideId: earnArgs['ride_id']?.toString() ?? '',
            bookingId: earnArgs['booking_id']?.toString() ?? earnArgs['ride_id']?.toString() ?? '',
            tripDate: earnArgs['trip_date']?.toString() ?? '',
            grossFare: (earnArgs['gross_fare'] as num?)?.toDouble() ?? 0.0,
            platformCommission: (earnArgs['platform_commission'] as num?)?.toDouble() ?? 0.0,
            commissionRate: (earnArgs['commission_rate'] as num?)?.toDouble() ?? 0.15,
            netEarnings: (earnArgs['net_earnings'] as num?)?.toDouble() ?? 0.0,
            otherDeductions: (earnArgs['other_deductions'] as num?)?.toDouble() ?? 0.0,
            distanceKm: (earnArgs['distance_km'] as num?)?.toDouble() ?? 0.0,
            durationMinutes: (earnArgs['duration_minutes'] as num?)?.toInt() ?? 0,
            paymentStatus: earnArgs['payment_status']?.toString() ?? 'Paid',
            paymentMethod: earnArgs['payment_method']?.toString() ?? 'Paid via UPI',
            pickupAddress: earnArgs['pickup_address']?.toString() ?? 'Pickup Point',
            destinationAddress: earnArgs['destination_address']?.toString() ?? 'Destination Point',
            passengerName: earnArgs['passenger_name']?.toString() ?? 'Passenger',
            vehicleType: earnArgs['vehicle_type']?.toString() ?? 'Saffar Auto',
          ),
        );
      case PaymentScreen.routeName:
        return MaterialPageRoute(
          builder: (_) => PaymentScreen(
            paymentScreenArguments:
                settings.arguments as PaymentScreenArguments,
          ),
        );
      case ActiveTripScreen.routeName:
        final tripArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => ActiveTripScreen(
            rideId: tripArgs['ride_id']?.toString() ?? '',
            otp: tripArgs['otp']?.toString() ?? '',
            driverName: tripArgs['driver_name']?.toString() ?? 'Driver',
            vehicleName: tripArgs['vehicle_name']?.toString() ?? tripArgs['vehicle_model']?.toString() ?? 'Vehicle',
            vehicleNumber: tripArgs['vehicle_number']?.toString() ?? '',
            driverTrips: tripArgs['driver_trips']?.toString() ?? '',
            driverRating: tripArgs['driver_rating']?.toString() ?? '5.0',
            driverPhone: tripArgs['driver_phone']?.toString() ?? '',
            driverImageUrl: tripArgs['driver_image_url']?.toString(),
            rideType: tripArgs['ride_type']?.toString() ?? 'Ride',
            fare: tripArgs['fare']?.toString() ?? tripArgs['fare_paid']?.toString() ?? '',
            pickupSpot: tripArgs['pickup_spot']?.toString() ?? tripArgs['pickup_address']?.toString() ?? '',
          ),
        );
      case RateReviewDriverScreen.routeName:
        final rateArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => RateReviewDriverScreen(
            rideId: rateArgs['ride_id']?.toString() ?? '',
            driverId: rateArgs['driver_id']?.toString() ?? '',
            driverName: rateArgs['driver_name']?.toString() ?? 'Driver',
            vehicleModel: rateArgs['vehicle_model']?.toString() ?? 'Vehicle',
            vehicleNumber: rateArgs['vehicle_number']?.toString() ?? '',
            driverRating: rateArgs['driver_rating']?.toString() ?? '5.0',
            totalTrips: rateArgs['total_trips']?.toString() ?? '',
            pickupAddress: rateArgs['pickup_address']?.toString() ?? '',
            dropAddress: rateArgs['drop_address']?.toString() ?? '',
            farePaid: rateArgs['fare_paid']?.toString() ?? '',
            paymentMethod: rateArgs['payment_method']?.toString() ?? 'Paid',
            distance: rateArgs['distance']?.toString() ?? '',
            duration: rateArgs['duration']?.toString() ?? '',
          ),
        );
      case RideConfirmationScreen.routeName:
        final confArgs = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => RideConfirmationScreen(
            pickupText: confArgs['pickup_text']?.toString() ?? '',
            destinationText: confArgs['destination_text']?.toString() ?? '',
            distanceText: confArgs['distance_text']?.toString() ?? '',
            durationText: confArgs['duration_text']?.toString() ?? '',
            pickupLat: (confArgs['pickup_lat'] as num?)?.toDouble(),
            pickupLon: (confArgs['pickup_lon'] as num?)?.toDouble(),
            destLat: (confArgs['dest_lat'] as num?)?.toDouble(),
            destLon: (confArgs['dest_lon'] as num?)?.toDouble(),
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
      case ForgotPasswordScreen.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(
            initialPhone: args?['phone'] as String?,
          ),
        );
      case ResetPasswordScreen.routeName:
        final resetArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            phone: resetArgs?['phone'] as String?,
            resetToken: resetArgs?['resetToken'] as String?,
          ),
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
