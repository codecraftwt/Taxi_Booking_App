import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/models/driver.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/utils/snackbar.dart';
import 'package:saffar_app/features/find_ride/domain/usecases/find_ride_driver_usecase.dart';
import 'package:saffar_app/features/find_ride/domain/usecases/open_caller_app_usecase.dart';
import 'package:saffar_app/features/find_ride/domain/usecases/share_driver_info_usecase.dart';

part 'ride_driver_state.dart';

class RideDriverCubit extends Cubit<RideDriverState> {
  RideDriverCubit() : super(const RideDriverInitial());

  final FindRideDriverUsecase _findRideDriverUsecase = FindRideDriverUsecase();
  final OpenCallerAppUsecase _openCallerAppUsecase = OpenCallerAppUsecase();
  final ShareDriverInfoUsecase _shareDriverInfoUsecase = ShareDriverInfoUsecase();

  Future<void> findRideDriver(
    BuildContext context,
    LatLng userSourcePosition,
  ) async {
    emit(const RideDriverLoading());

    final result = await _findRideDriverUsecase.call(userSourcePosition);

    result.fold(
      (l) {
        Snackbar.of(context).show(
          l.message ??
              'There was some problem in finding driver. Please try again.',
        );
      },
      (r) {
        emit(RideDriverGot(
          driver: r.driver,
          points: r.points,
          otp: r.otp,
        ));
      },
    );
  }

  void moveRideDriverByOnePoint() {
    if (state is RideDriverGot) {
      final RideDriverGot rideDriverGotState = state as RideDriverGot;

      List<LatLng> movedPoints = [];

      if (rideDriverGotState.points.length > 1) {
        movedPoints = rideDriverGotState.points.toList().sublist(1);
      }

      emit(RideDriverGot(
        driver: rideDriverGotState.driver,
        points: movedPoints,
        otp: rideDriverGotState.otp,
      ));
    }
  }

  void emitRideDriverInitialState() {
    emit(const RideDriverInitial());
  }

  void openCallerApp([String? phoneNumber]) {
    final phone = (phoneNumber != null && phoneNumber.isNotEmpty)
        ? phoneNumber
        : (state is RideDriverGot ? (state as RideDriverGot).driver.phone : '');
    if (phone.isNotEmpty) {
      _openCallerAppUsecase.call(phone);
    }
  }

  void shareDriverInfo([Driver? customDriver]) {
    final driver = customDriver ?? (state is RideDriverGot ? (state as RideDriverGot).driver : null);
    if (driver != null) {
      _shareDriverInfoUsecase.call(driver);
    }
  }
}
