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
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
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
        final token = response['data']['token'];
        _wsService.connect(token);
        emit(AuthAuthenticated(user: user, token: token));
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
