part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSubmitted(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AuthRegisterSubmitted extends AuthEvent {
  final String fullName;
  final String email;
  final String password;
  final String currency;

  const AuthRegisterSubmitted({
    required this.fullName,
    required this.email,
    required this.password,
    required this.currency,
  });

  @override
  List<Object> get props => [fullName, email, password, currency];
}

class AuthLogoutRequested extends AuthEvent {}
