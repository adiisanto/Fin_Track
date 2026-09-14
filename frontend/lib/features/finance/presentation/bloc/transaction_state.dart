import 'package:equatable/equatable.dart';
import '../../domain/models.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();
  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionFormDataLoading extends TransactionState {}

class TransactionFormDataLoaded extends TransactionState {
  final List<Currency> currencies;
  final List<PaymentMethod> paymentMethods;
  
  const TransactionFormDataLoaded(this.currencies, this.paymentMethods);

  @override
  List<Object?> get props => [currencies, paymentMethods];
}

class TransactionRateCalculated extends TransactionState {
  final double rate;
  final double convertedAmount;
  
  const TransactionRateCalculated(this.rate, this.convertedAmount);

  @override
  List<Object?> get props => [rate, convertedAmount];
}

class TransactionSubmitting extends TransactionState {}

class TransactionSubmitSuccess extends TransactionState {}

class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}
