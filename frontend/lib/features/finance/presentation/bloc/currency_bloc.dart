import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models.dart';
import '../../data/finance_repository.dart';

// EVENTS
abstract class CurrencyEvent {}

class CurrencyFetchRequested extends CurrencyEvent {}

class CurrencyCreateRequested extends CurrencyEvent {
  final String code;
  final String name;
  final String symbol;
  final bool isActive;

  CurrencyCreateRequested({
    required this.code,
    required this.name,
    required this.symbol,
    this.isActive = true,
  });
}

class CurrencyDeleteRequested extends CurrencyEvent {
  final String code;

  CurrencyDeleteRequested(this.code);
}

// STATES
abstract class CurrencyState {}

class CurrencyInitial extends CurrencyState {}

class CurrencyLoading extends CurrencyState {}

class CurrencyLoaded extends CurrencyState {
  final List<Currency> currencies;

  CurrencyLoaded(this.currencies);
}

class CurrencyOperationSuccess extends CurrencyState {
  final String message;

  CurrencyOperationSuccess(this.message);
}

class CurrencyError extends CurrencyState {
  final String errorMessage;

  CurrencyError(this.errorMessage);
}

// BLOC
class CurrencyBloc extends Bloc<CurrencyEvent, CurrencyState> {
  final FinanceRepository financeRepository;

  CurrencyBloc({required this.financeRepository}) : super(CurrencyInitial()) {
    on<CurrencyFetchRequested>(_onFetchRequested);
    on<CurrencyCreateRequested>(_onCreateRequested);
    on<CurrencyDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onFetchRequested(
    CurrencyFetchRequested event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(CurrencyLoading());
    try {
      final currencies = await financeRepository.getCurrencies(includeInactive: true);
      emit(CurrencyLoaded(currencies));
    } catch (e) {
      emit(CurrencyError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(
    CurrencyCreateRequested event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(CurrencyLoading());
    try {
      await financeRepository.addCurrency(
        code: event.code,
        name: event.name,
        symbol: event.symbol,
        isActive: event.isActive,
      );
      emit(CurrencyOperationSuccess('Mata uang berhasil ditambahkan.'));
      add(CurrencyFetchRequested());
    } catch (e) {
      emit(CurrencyError(e.toString()));
      add(CurrencyFetchRequested()); // Refresh data
    }
  }

  Future<void> _onDeleteRequested(
    CurrencyDeleteRequested event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(CurrencyLoading());
    try {
      await financeRepository.deleteCurrency(event.code);
      emit(CurrencyOperationSuccess('Mata uang berhasil dihapus.'));
      add(CurrencyFetchRequested());
    } catch (e) {
      emit(CurrencyError(e.toString()));
      add(CurrencyFetchRequested()); // Refresh data
    }
  }
}
