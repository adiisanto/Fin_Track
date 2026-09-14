import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/user.dart';
import '../../data/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginSubmitted>(_onAuthLoginSubmitted);
    on<AuthRegisterSubmitted>(_onAuthRegisterSubmitted);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.checkAuth();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onAuthLoginSubmitted(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(email: event.email, password: event.password);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onAuthRegisterSubmitted(AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.register(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
        baseCurrency: event.currency,
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onAuthLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(Unauthenticated());
  }
}
