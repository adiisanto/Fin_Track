import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FinanceRepository financeRepository;

  DashboardBloc({required this.financeRepository}) : super(DashboardInitial()) {
    on<DashboardFetchRequested>(_onFetchRequested);
  }

  Future<void> _onFetchRequested(DashboardFetchRequested event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final summary = await financeRepository.getDashboardSummary(timeframe: event.timeframe);
      emit(DashboardLoaded(summary));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
