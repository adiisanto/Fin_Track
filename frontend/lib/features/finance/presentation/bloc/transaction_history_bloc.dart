import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import 'transaction_history_event.dart';
import 'transaction_history_state.dart';

class TransactionHistoryBloc extends Bloc<TransactionHistoryEvent, TransactionHistoryState> {
  final FinanceRepository repository;

  TransactionHistoryBloc({required this.repository}) : super(TransactionHistoryInitial()) {
    on<TransactionHistoryFetchRequested>(_onFetchRequested);
    on<TransactionHistoryDeleteRequested>(_onDeleteRequested);
    on<TransactionHistoryUpdateRequested>(_onUpdateRequested);
    on<DeletedTransactionsFetchRequested>(_onFetchDeletedRequested);
  }

  Future<void> _onFetchRequested(
    TransactionHistoryFetchRequested event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    emit(TransactionHistoryLoading());
    try {
      final transactions = await repository.getTransactions(
        startDate: event.startDate,
        endDate: event.endDate,
        type: event.type,
        notes: event.notes,
        paymentMethodId: event.paymentMethodId,
      );
      emit(TransactionHistoryLoaded(transactions));
    } catch (e) {
      emit(TransactionHistoryError(e.toString()));
    }
  }

  Future<void> _onDeleteRequested(
    TransactionHistoryDeleteRequested event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    emit(TransactionHistoryLoading());
    try {
      await repository.deleteTransaction(event.id);
      emit(const TransactionHistoryOperationSuccess('Transaksi berhasil dihapus'));
      // We don't automatically refetch here, the UI can trigger it after showing a snackbar
    } catch (e) {
      emit(TransactionHistoryError(e.toString()));
    }
  }

  Future<void> _onUpdateRequested(
    TransactionHistoryUpdateRequested event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    emit(TransactionHistoryLoading());
    try {
      await repository.updateTransaction(
        event.id,
        type: event.type,
        currencyCode: event.currencyCode,
        amount: event.amount,
        paymentMethodId: event.paymentMethodId,
        notes: event.notes,
        transactionDate: event.transactionDate,
      );
      emit(const TransactionHistoryOperationSuccess('Transaksi berhasil diperbarui'));
    } catch (e) {
      emit(TransactionHistoryError(e.toString()));
    }
  }

  Future<void> _onFetchDeletedRequested(
    DeletedTransactionsFetchRequested event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    emit(TransactionHistoryLoading());
    try {
      final deletedTransactions = await repository.getDeletedTransactions();
      emit(DeletedTransactionsLoaded(deletedTransactions));
    } catch (e) {
      emit(TransactionHistoryError(e.toString()));
    }
  }
}
