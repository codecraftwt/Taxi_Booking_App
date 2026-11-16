import 'package:saffar_app/core/errors/custom_exception.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';
import 'package:saffar_app/features/driver/data/repositories/driver_repo.dart';
import 'package:saffar_app/core/service_locator.dart';

import 'package:saffar_app/core/errors/failure.dart';

class InitSplashUsecase {
  final UserRepo _userRepo = sl<UserRepo>();
  final DriverRepo _driverRepo = sl<DriverRepo>();

  Future<Failure?> call() async {
    try {
      await _userRepo.initUserRepo();
      await _driverRepo.initDriverRepo();
      return null;
    } on CustomException catch (e) {
      return Failure.fromCustomException(e);
    }
  }
}
