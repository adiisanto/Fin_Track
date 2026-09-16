import 'package:equatable/equatable.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

class TransactionFormDataRequested extends TransactionEvent {}

class TransactionRateRequested extends TransactionEvent {
  final String fromCurrency;
  final String toCurrency;
  final double amount;
  
  const TransactionRateRequested(this.fromCurrency, this.toCurrency, this.amount);

  @override
  List<Object?> get props => [fromCurrency, toCurrency, amount];
}

class TransactionSubmitRequested extends TransactionEvent {
  final String type;
  final String currencyCode;
  final double amount;
  final String paymentMethodId;
  final String? notes;

  const TransactionSubmitRequested({
    required this.type,
    required this.currencyCode,
    required this.amount,
    required this.paymentMethodId,
    this.notes,
  });

  @override
  List<Object?> get props => [type, currencyCode, amount, paymentMethodId, notes];
}
