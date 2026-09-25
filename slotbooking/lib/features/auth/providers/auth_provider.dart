import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slotbooking/core/api/api_services.dart';
import 'package:slotbooking/core/api/session_manager.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool success;

  const AuthState({this.isLoading = false, this.error, this.success = false});

  AuthState copyWith({bool? isLoading, String? error, bool? success}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        success: success ?? this.success,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  final AuthApi _api = AuthApi();

  Future<String?> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email, password);
      final role = data['role']?.toString() ?? data['user']?['role']?.toString();
      state = state.copyWith(isLoading: false, success: true);
      return role;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<String?> verifyPhoneOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.verifyOtp(phone, otp);
      final role = data['role']?.toString() ?? data['user']?['role']?.toString() ?? 'user';
      state = state.copyWith(isLoading: false, success: true);
      return role;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    state = state.copyWith(
      isLoading: false,
      error: 'Admin registration belongs to the admin panel.',
    );
    return false;
  }

  void clearError() => state = const AuthState();
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  return SessionManager.currentUser?['role']?.toString();
});
