import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String baseCurrency;
  final bool isSuperuser;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.baseCurrency,
    this.isSuperuser = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      baseCurrency: json['base_currency'],
      isSuperuser: json['is_superuser'] ?? false,
    );
  }

  @override
  List<Object?> get props => [id, fullName, email, baseCurrency, isSuperuser];
}
