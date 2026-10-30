import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/core/utils/snackbar.dart';
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
    emit(UserState(
      currentUser: user,
      token: token,
    ));
  }

  /// Gets current user info from local storage and emits the current user.
  void getCurrentUserFromLocalStorageAndEmitCurrentUser() {
    final User? currentUser = _getUserFromLocalStorageUsecase.call();
    final String? token = _getTokenFromLocalStorageUsecase.call();

    emit(UserState(
      currentUser: currentUser,
      token: token,
    ));
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? email,
    String? imageUrl,
  }) async {
    if (state.token == null) return false;

    emit(state.copyWith(isLoading: true));
    try {
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name;
      if (email != null) fields['email'] = email;
      if (imageUrl != null) fields['image_url'] = imageUrl;

      final updatedUser = await _userRepo.updateUserProfile(state.token!, fields);
      emit(UserState(
        currentUser: updatedUser,
        token: state.token,
        isLoading: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(isLoading: false));
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
