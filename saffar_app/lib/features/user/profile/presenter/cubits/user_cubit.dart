import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/core/utils/snackbar.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';
import 'package:saffar_app/features/user/domain/usecases/delete_token_from_local_storage_usecase.dart';
import 'package:saffar_app/features/user/domain/usecases/delete_user_from_loca_storage_usecase.dart';
import 'package:saffar_app/features/user/domain/usecases/get_token_from_local_storage_usecase.dart';
import 'package:saffar_app/features/user/domain/usecases/get_user_from_local_storage_usecase.dart';

import '../../data/models/user.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(const UserState());

  final GetUserFromLocalStorageUsecase _getUserFromLocalStorageUsecase =
      GetUserFromLocalStorageUsecase();
  final GetTokenFromLocalStorageUsecase _getTokenFromLocalStorageUsecase =
      GetTokenFromLocalStorageUsecase();
  final DeleteTokenFromLocalStorageUsecase _deleteTokenFromLocalStorageUsecase =
      DeleteTokenFromLocalStorageUsecase();
  final DeleteUserFromLocalStorageUsecase _deleteUserFromLocalStorageUsecase =
      DeleteUserFromLocalStorageUsecase();
  final UserRepo _userRepo = sl<UserRepo>();

  /// Emits user and token state with new user and token value.
  void emitUserAndToken(User user, String token) {
    try {
      sl<RideRepo>().initRidesRepo(token, user.id);
    } catch (_) {}

    emit(UserState(
      currentUser: user,
      token: token,
    ));
  }

  /// Gets current user info from local storage and emits the current user.
  void getCurrentUserFromLocalStorageAndEmitCurrentUser() {
    final User? currentUser = _getUserFromLocalStorageUsecase.call();
    final String? token = _getTokenFromLocalStorageUsecase.call();

    if (token != null && currentUser != null) {
      try {
        sl<RideRepo>().initRidesRepo(token, currentUser.id);
      } catch (_) {}
    }

    emit(UserState(
      currentUser: currentUser,
      token: token,
    ));
  }

  /// Submits support ticket or emergency SOS to backend
  Future<Map<String, dynamic>?> submitSupportTicket({
    required String category,
    required String message,
    String? rideId,
  }) async {
    final t = state.token ?? _getTokenFromLocalStorageUsecase.call();
    if (t == null) return null;
    try {
      return await _userRepo.submitSupportTicket(
        t,
        category: category,
        message: message,
        rideId: rideId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? email,
    String? imageUrl,
    String? phone,
    String? address,
  }) async {
    final t = state.token ?? _getTokenFromLocalStorageUsecase.call();
    if (t == null) return false;

    emit(state.copyWith(isLoading: true));
    try {
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name;
      if (email != null) fields['email'] = email;
      if (imageUrl != null) fields['image_url'] = imageUrl;
      if (phone != null) fields['phone'] = phone;
      if (address != null) fields['address'] = address;

      final updatedUser = await _userRepo.updateUserProfile(t, fields);
      emit(UserState(
        currentUser: updatedUser,
        token: t,
        isLoading: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      return false;
    }
  }

  /// Fetches live user profile directly from database via backend
  Future<void> fetchAndRefreshUserProfile() async {
    final t = state.token ?? _getTokenFromLocalStorageUsecase.call();
    final u = state.currentUser ?? _getUserFromLocalStorageUsecase.call();
    if (t == null || u == null) return;

    try {
      final liveUser = await _userRepo.fetchUserProfile(t, u.id);
      await _userRepo.putUserMapInLocalStorage(liveUser.toMap());
      emit(UserState(
        currentUser: liveUser,
        token: t,
        isLoading: false,
      ));
    } catch (_) {}
  }

  /// Adds money to user's database wallet
  Future<bool> addMoneyToWallet(double amount) async {
    final t = state.token ?? _getTokenFromLocalStorageUsecase.call();
    if (t == null) return false;

    try {
      final updatedUser = await _userRepo.addMoneyToWallet(t, amount);
      emit(UserState(
        currentUser: updatedUser,
        token: t,
        isLoading: false,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  void deleteCurrentUserFromLocalStorageAndEmitCurrentUser(
      BuildContext context) async {
    final List<bool> deleteUserResultList = await Future.wait<bool>([
      _deleteTokenFromLocalStorageUsecase.call(),
      _deleteUserFromLocalStorageUsecase.call(),
    ]);

    for (final result in deleteUserResultList) {
      if (!result) {
        if (context.mounted) {
          Snackbar.of(context).show('Logout failed');
        }
        return;
      }
    }

    emit(const UserState());
  }
}
