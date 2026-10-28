import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

// Current user state
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;
  final bool initialized;

  const AuthState({this.user, this.loading = false, this.error, this.initialized = false});

  bool get isLoggedIn => user != null;
  AuthState copyWith({UserModel? user, bool? loading, String? error, bool? initialized}) =>
      AuthState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: error,
        initialized: initialized ?? this.initialized,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final hasToken = await StorageService.hasToken();
    if (hasToken) {
      try {
        final res = await ApiService.get(ApiConstants.me);
        final user = UserModel.fromJson(res.data['user']);
        state = AuthState(user: user, initialized: true);
      } catch (_) {
        await StorageService.deleteToken();
        state = const AuthState(initialized: true);
      }
    } else {
      state = const AuthState(initialized: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiService.post(ApiConstants.login,
          data: {'email': email, 'password': password});
      await StorageService.saveToken(res.data['token']);
      final user = UserModel.fromJson(res.data['user']);
      state = AuthState(user: user, initialized: true);
      return true;
    } catch (e) {
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password, String phone) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiService.post(ApiConstants.register, data: {
        'name': name, 'email': email, 'password': password,
        'password_confirmation': password, 'phone': phone,
      });
      await StorageService.saveToken(res.data['token']);
      final user = UserModel.fromJson(res.data['user']);
      state = AuthState(user: user, initialized: true);
      return true;
    } catch (e) {
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    try { await ApiService.post(ApiConstants.logout); } catch (_) {}
    await StorageService.deleteToken();
    state = const AuthState(initialized: true);
  }

  Future<bool> updateProfile(String name, String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiService.patch(ApiConstants.profile, data: {
        'name': name, 'email': email,
      });
      final updated = res.data['user'] as Map<String, dynamic>;
      final newUser = state.user?.copyWith(
        name: updated['name'], email: updated['email'], phone: updated['phone'],
      );
      state = AuthState(user: newUser, initialized: true);
      return true;
    } catch (e) {
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  Future<bool> updateAvatar(File file) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path),
      });
      final res = await ApiService.post(ApiConstants.profileAvatar, data: formData);
      final newUser = state.user?.copyWith(avatarUrl: res.data['avatar']);
      state = AuthState(user: newUser, initialized: true);
      return true;
    } catch (e) {
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  /// Deletes the account on the server, then clears local session state.
  /// On failure (wrong password, or an order still in progress) the local
  /// session is left untouched and the message is surfaced via state.error.
  Future<bool> deleteAccount(String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await ApiService.delete(ApiConstants.profile, data: {'password': password});
      await StorageService.deleteToken();
      state = const AuthState(initialized: true);
      return true;
    } catch (e) {
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
