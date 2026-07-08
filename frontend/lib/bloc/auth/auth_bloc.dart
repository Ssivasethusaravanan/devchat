import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ===== Events =====
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;
  AuthLoginRequested({required this.username, required this.password});
  @override
  List<Object?> get props => [username, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  AuthRegisterRequested({required this.username, required this.email, required this.password});
  @override
  List<Object?> get props => [username, email, password];
}

class AuthVerifyEmailRequested extends AuthEvent {
  final String email;
  final String code;
  AuthVerifyEmailRequested({required this.email, required this.code});
  @override
  List<Object?> get props => [email, code];
}

class AuthResendVerificationRequested extends AuthEvent {
  final String email;
  AuthResendVerificationRequested({required this.email});
  @override
  List<Object?> get props => [email];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;
  AuthForgotPasswordRequested({required this.email});
  @override
  List<Object?> get props => [email];
}

class AuthResetPasswordRequested extends AuthEvent {
  final String email;
  final String code;
  final String newPassword;
  AuthResetPasswordRequested({required this.email, required this.code, required this.newPassword});
  @override
  List<Object?> get props => [email, code, newPassword];
}

class AuthChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;
  AuthChangePasswordRequested({required this.currentPassword, required this.newPassword});
  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class AuthUpdateProfileRequested extends AuthEvent {
  final String? username;
  final String? avatarUrl;
  final bool? hideLastSeen;
  AuthUpdateProfileRequested({this.username, this.avatarUrl, this.hideLastSeen});
  @override
  List<Object?> get props => [username, avatarUrl, hideLastSeen];
}

class AuthDeleteAccountRequested extends AuthEvent {
  final String password;
  AuthDeleteAccountRequested({required this.password});
  @override
  List<Object?> get props => [password];
}

// ===== States =====
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String token;
  AuthAuthenticated({required this.user, required this.token});
  @override
  List<Object?> get props => [user, token];
}

class AuthUnauthenticated extends AuthState {}

class AuthRegistered extends AuthState {
  final String email;
  final String message;
  AuthRegistered({required this.email, required this.message});
  @override
  List<Object?> get props => [email, message];
}

class AuthEmailVerified extends AuthState {
  final String message;
  AuthEmailVerified({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthVerificationResent extends AuthState {
  final String email;
  final String message;
  AuthVerificationResent({required this.email, required this.message});
  @override
  List<Object?> get props => [email, message];
}

class AuthForgotPasswordSent extends AuthState {
  final String email;
  final String message;
  AuthForgotPasswordSent({required this.email, required this.message});
  @override
  List<Object?> get props => [email, message];
}

class AuthPasswordResetSuccess extends AuthState {
  final String message;
  AuthPasswordResetSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthActionSuccess extends AuthState {
  final String message;
  AuthActionSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;
  AuthError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ===== Bloc =====
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthVerifyEmailRequested>(_onVerifyEmailRequested);
    on<AuthResendVerificationRequested>(_onResendVerification);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthResetPasswordRequested>(_onResetPasswordRequested);
    on<AuthChangePasswordRequested>(_onChangePasswordRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (kIsWeb) {
        // Web: Can't read HttpOnly cookies — just call /auth/me directly.
        // The browser sends the access_token cookie automatically.
        final response = await _apiService.getMe();
        if (response['success'] == true && response['data'] != null) {
          final user = UserModel.fromJson(response['data']);
          _wsService.connect(); // No token needed — cookies handle auth
          emit(AuthAuthenticated(user: user, token: ''));
        } else {
          await _apiService.logout();
          emit(AuthUnauthenticated());
        }
      } else {
        // Mobile: Check for stored token first
        final token = await _apiService.getToken();
        if (token == null) {
          emit(AuthUnauthenticated());
          return;
        }

        final response = await _apiService.getMe();
        if (response['success'] == true && response['data'] != null) {
          final user = UserModel.fromJson(response['data']);
          _wsService.connect(token);
          emit(AuthAuthenticated(user: user, token: token));
        } else {
          await _apiService.logout();
          emit(AuthUnauthenticated());
        }
      }
    } catch (e) {
      await _apiService.logout();
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.login(event.username, event.password);
      if (response['success'] == true && response['data'] != null) {
        final user = UserModel.fromJson(response['data']['user']);
        if (kIsWeb) {
          // Web: Token is in HttpOnly cookie (not in response body).
          // Connect WS without token — cookies sent automatically.
          _wsService.connect();
          emit(AuthAuthenticated(user: user, token: ''));
        } else {
          // Mobile: Token is in the response body.
          final token = response['data']['token'] ?? '';
          _wsService.connect(token);
          emit(AuthAuthenticated(user: user, token: token));
        }
      } else {
        emit(AuthError(message: response['error'] ?? 'Login failed'));
      }
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message: message));
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.register(event.username, event.email, event.password);
      if (response['success'] == true) {
        emit(AuthRegistered(
          email: event.email,
          message: response['message'] ?? 'Registration successful! Check your email for verification code.',
        ));
      } else {
        emit(AuthError(message: response['error'] ?? 'Registration failed'));
      }
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message: message));
    }
  }

  Future<void> _onVerifyEmailRequested(AuthVerifyEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.verifyEmail(event.email, event.code);
      if (response['success'] == true) {
        emit(AuthEmailVerified(
          message: response['message'] ?? 'Email verified! You can now log in.',
        ));
      } else {
        emit(AuthError(message: response['error'] ?? 'Verification failed'));
      }
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message: message));
    }
  }

  Future<void> _onResendVerification(AuthResendVerificationRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.resendVerification(event.email);
      if (response['success'] == true) {
        emit(AuthVerificationResent(
          email: event.email,
          message: response['message'] ?? 'Verification code resent!',
        ));
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to resend'));
      }
    } catch (e) {
      final message = _extractErrorMessage(e);
      emit(AuthError(message: message));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    _wsService.disconnect();
    await _apiService.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onForgotPasswordRequested(AuthForgotPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.forgotPassword(event.email);
      if (response['success'] == true) {
        emit(AuthForgotPasswordSent(email: event.email, message: response['message'] ?? 'Reset code sent!'));
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to send reset code'));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onResetPasswordRequested(AuthResetPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.resetPassword(event.email, event.code, event.newPassword);
      if (response['success'] == true) {
        emit(AuthPasswordResetSuccess(message: response['message'] ?? 'Password reset successfully!'));
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to reset password'));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  Future<void> _onChangePasswordRequested(AuthChangePasswordRequested event, Emitter<AuthState> emit) async {
    final currentState = state;
    emit(AuthLoading());
    try {
      final response = await _apiService.changePassword(event.currentPassword, event.newPassword);
      if (response['success'] == true) {
        emit(AuthActionSuccess(message: response['message'] ?? 'Password updated successfully.'));
        if (currentState is AuthAuthenticated) {
          emit(currentState);
        }
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to update password'));
        if (currentState is AuthAuthenticated) emit(currentState);
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
      if (currentState is AuthAuthenticated) emit(currentState);
    }
  }

  Future<void> _onUpdateProfileRequested(AuthUpdateProfileRequested event, Emitter<AuthState> emit) async {
    final currentState = state;
    emit(AuthLoading());
    try {
      final response = await _apiService.updateProfile(username: event.username, avatarUrl: event.avatarUrl, hideLastSeen: event.hideLastSeen);
      if (response['success'] == true && response['data'] != null) {
        final updatedUser = UserModel.fromJson(response['data']);
        emit(AuthActionSuccess(message: response['message'] ?? 'Profile updated successfully.'));
        if (currentState is AuthAuthenticated) {
          emit(AuthAuthenticated(user: updatedUser, token: currentState.token));
        }
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to update profile'));
        if (currentState is AuthAuthenticated) emit(currentState);
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
      if (currentState is AuthAuthenticated) emit(currentState);
    }
  }

  Future<void> _onDeleteAccountRequested(AuthDeleteAccountRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _apiService.deleteAccount(event.password);
      if (response['success'] == true) {
        _wsService.disconnect();
        emit(AuthUnauthenticated());
      } else {
        emit(AuthError(message: response['error'] ?? 'Failed to delete account'));
      }
    } catch (e) {
      emit(AuthError(message: _extractErrorMessage(e)));
    }
  }

  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      final str = error.toString();
      // Try to extract Dio error message
      if (str.contains('error')) {
        return str.replaceAll('Exception: ', '');
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
