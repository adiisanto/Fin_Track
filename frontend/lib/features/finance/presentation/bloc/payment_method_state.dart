import 'package:equatable/equatable.dart';
import '../../domain/models.dart';

abstract class PaymentMethodState extends Equatable {
  const PaymentMethodState();

  @override
  List<Object?> get props => [];
}

class PaymentMethodInitial extends PaymentMethodState {}

class PaymentMethodLoading extends PaymentMethodState {}

class PaymentMethodLoaded extends PaymentMethodState {
  final List<PaymentMethod> paymentMethods;
  final List<PaymentMethod> publicTemplates;

  const PaymentMethodLoaded({
    this.paymentMethods = const [],
    this.publicTemplates = const [],
  });

  PaymentMethodLoaded copyWith({
    List<PaymentMethod>? paymentMethods,
    List<PaymentMethod>? publicTemplates,
  }) {
    return PaymentMethodLoaded(
      paymentMethods: paymentMethods ?? this.paymentMethods,
      publicTemplates: publicTemplates ?? this.publicTemplates,
    );
  }

  @override
  List<Object?> get props => [paymentMethods, publicTemplates];
}

class PaymentMethodError extends PaymentMethodState {
  final String message;

  const PaymentMethodError(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentMethodActionLoading extends PaymentMethodState {}

class PaymentMethodActionSuccess extends PaymentMethodState {
  final String message;

  const PaymentMethodActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TemplatePreviewLoaded extends PaymentMethodState {
  final Map<String, dynamic> previewData;

  const TemplatePreviewLoaded(this.previewData);

  @override
  List<Object?> get props => [previewData];
}
