import 'package:equatable/equatable.dart';
import '../../domain/models.dart';

abstract class TransactionHistoryState extends Equatable {
  const TransactionHistoryState();

  @override
  List<Object?> get props => [];
}

class TransactionHistoryInitial extends TransactionHistoryState {}

class TransactionHistoryLoading extends TransactionHistoryState {}

class TransactionHistoryLoaded extends TransactionHistoryState {
  final List<Transaction> transactions;

  const TransactionHistoryLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class DeletedTransactionsLoaded extends TransactionHistoryState {
  final List<DeletedTransaction> deletedTransactions;

  const DeletedTransactionsLoaded(this.deletedTransactions);

  @override
  List<Object?> get props => [deletedTransactions];
}

class TransactionHistoryOperationSuccess extends TransactionHistoryState {
  final String message;

  const TransactionHistoryOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionHistoryError extends TransactionHistoryState {
  final String message;

  const TransactionHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}
