import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final FinanceRepository financeRepository;

  TransactionBloc({required this.financeRepository}) : super(TransactionInitial()) {
    on<TransactionFormDataRequested>(_onFormDataRequested);
    on<TransactionRateRequested>(_onRateRequested);
    on<TransactionSubmitRequested>(_onSubmitRequested);
  }

  Future<void> _onFormDataRequested(TransactionFormDataRequested event, Emitter<TransactionState> emit) async {
    emit(TransactionFormDataLoading());
    try {
      final currencies = await financeRepository.getCurrencies();
      final methods = await financeRepository.getPaymentMethods();
      emit(TransactionFormDataLoaded(currencies, methods));
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onRateRequested(TransactionRateRequested event, Emitter<TransactionState> emit) async {
    try {
      final rate = await financeRepository.getLatestCurrencyRate(event.fromCurrency, event.toCurrency);
      emit(TransactionRateCalculated(rate, rate * event.amount));
    } catch (e) {
      // Don't emit full error to not break the UI if rate fails, maybe emit partial or error
      emit(TransactionError(e.toString()));
    }
  }

  Future<void> _onSubmitRequested(TransactionSubmitRequested event, Emitter<TransactionState> emit) async {
    emit(TransactionSubmitting());
    try {
      await financeRepository.createTransaction(
        type: event.type,
        currencyCode: event.currencyCode,
        amount: event.amount,
        paymentMethodId: event.paymentMethodId,
        notes: event.notes,
      );
      emit(TransactionSubmitSuccess());
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }
}
