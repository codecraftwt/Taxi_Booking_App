part of 'user_cubit.dart';

@immutable
/// Contains the state of current user and its token.
class UserState {
  const UserState({
    this.currentUser,
    this.token,
    this.isLoading = false,
  });

  final User? currentUser;
  final String? token;
  final bool isLoading;

  bool get isLoggedIn => currentUser != null && token != null;

  UserState copyWith({
    User? currentUser,
    String? token,
    bool? isLoading,
  }) {
    return UserState(
      currentUser: currentUser ?? this.currentUser,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
