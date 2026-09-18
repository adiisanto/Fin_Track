import 'package:equatable/equatable.dart';

abstract class TransactionHistoryEvent extends Equatable {
  const TransactionHistoryEvent();

  @override
  List<Object?> get props => [];
}

class TransactionHistoryFetchRequested extends TransactionHistoryEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? type;
  final String? notes;
  final String? paymentMethodId;

  const TransactionHistoryFetchRequested({
    this.startDate,
    this.endDate,
    this.type,
    this.notes,
    this.paymentMethodId,
  });

  @override
  List<Object?> get props => [startDate, endDate, type, notes, paymentMethodId];
}

class TransactionHistoryDeleteRequested extends TransactionHistoryEvent {
  final String id;

  const TransactionHistoryDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class TransactionHistoryUpdateRequested extends TransactionHistoryEvent {
  final String id;
  final String? type;
  final String? currencyCode;
  final double? amount;
  final String? paymentMethodId;
  final String? notes;
  final DateTime? transactionDate;

  const TransactionHistoryUpdateRequested({
    required this.id,
    this.type,
    this.currencyCode,
    this.amount,
    this.paymentMethodId,
    this.notes,
    this.transactionDate,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        currencyCode,
        amount,
        paymentMethodId,
        notes,
        transactionDate,
      ];
}

class DeletedTransactionsFetchRequested extends TransactionHistoryEvent {}
