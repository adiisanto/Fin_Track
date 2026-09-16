import 'package:equatable/equatable.dart';

abstract class PaymentMethodEvent extends Equatable {
  const PaymentMethodEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentMethods extends PaymentMethodEvent {}

class CreatePaymentMethod extends PaymentMethodEvent {
  final String code;
  final String name;
  final String? fromAccount;
  final bool isActive;

  const CreatePaymentMethod({
    required this.code,
    required this.name,
    this.fromAccount,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [code, name, fromAccount, isActive];
}

class UpdatePaymentMethod extends PaymentMethodEvent {
  final String id;
  final String? code;
  final String? name;
  final String? fromAccount;
  final bool? isActive;

  const UpdatePaymentMethod({
    required this.id,
    this.code,
    this.name,
    this.fromAccount,
    this.isActive,
  });

  @override
  List<Object?> get props => [id, code, name, fromAccount, isActive];
}

class DeletePaymentMethod extends PaymentMethodEvent {
  final String id;

  const DeletePaymentMethod(this.id);

  @override
  List<Object?> get props => [id];
}

class PreviewTemplate extends PaymentMethodEvent {
  final String templateId;

  const PreviewTemplate(this.templateId);

  @override
  List<Object?> get props => [templateId];
}

class CopyTemplate extends PaymentMethodEvent {
  final String templateId;

  const CopyTemplate(this.templateId);

  @override
  List<Object?> get props => [templateId];
}
