import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/models.dart';
import '../../data/finance_repository.dart';

// States
abstract class CoaState extends Equatable {
  const CoaState();
  
  @override
  List<Object?> get props => [];
}

class CoaInitial extends CoaState {}
class CoaLoading extends CoaState {}
class CoaLoaded extends CoaState {
  final List<MSTAccount> accounts;
  const CoaLoaded(this.accounts);
  @override
  List<Object?> get props => [accounts];
}
class CoaError extends CoaState {
  final String message;
  const CoaError(this.message);
  @override
  List<Object?> get props => [message];
}
class CoaActionSuccess extends CoaState {
  final String message;
  const CoaActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

// Events
abstract class CoaEvent extends Equatable {
  const CoaEvent();
  @override
  List<Object?> get props => [];
}

class FetchCoaAccounts extends CoaEvent {
  final bool includeInactive;
  final String? search;
  const FetchCoaAccounts({this.includeInactive = false, this.search});
  @override
  List<Object?> get props => [includeInactive, search];
}

class CreateCoaAccount extends CoaEvent {
  final Map<String, dynamic> data;
  const CreateCoaAccount(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateCoaAccount extends CoaEvent {
  final String id;
  final Map<String, dynamic> data;
  const UpdateCoaAccount(this.id, this.data);
  @override
  List<Object?> get props => [id, data];
}

class DeleteCoaAccount extends CoaEvent {
  final String id;
  const DeleteCoaAccount(this.id);
  @override
  List<Object?> get props => [id];
}

// Bloc
class CoaBloc extends Bloc<CoaEvent, CoaState> {
  final FinanceRepository financeRepository;
  bool _lastIncludeInactive = false;
  String? _lastSearch;

  CoaBloc({required this.financeRepository}) : super(CoaInitial()) {
    on<FetchCoaAccounts>(_onFetchCoaAccounts);
    on<CreateCoaAccount>(_onCreateCoaAccount);
    on<UpdateCoaAccount>(_onUpdateCoaAccount);
    on<DeleteCoaAccount>(_onDeleteCoaAccount);
  }

  Future<void> _onFetchCoaAccounts(FetchCoaAccounts event, Emitter<CoaState> emit) async {
    _lastIncludeInactive = event.includeInactive;
    _lastSearch = event.search;
    emit(CoaLoading());
    try {
      final accounts = await financeRepository.getCoaAccounts(
        includeInactive: event.includeInactive,
        search: event.search,
      );
      emit(CoaLoaded(accounts));
    } catch (e) {
      emit(CoaError(e.toString()));
    }
  }

  Future<void> _onCreateCoaAccount(CreateCoaAccount event, Emitter<CoaState> emit) async {
    emit(CoaLoading());
    try {
      await financeRepository.createCoaAccount(event.data);
      emit(const CoaActionSuccess('Akun berhasil dibuat'));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    } catch (e) {
      emit(CoaError(e.toString()));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    }
  }

  Future<void> _onUpdateCoaAccount(UpdateCoaAccount event, Emitter<CoaState> emit) async {
    emit(CoaLoading());
    try {
      await financeRepository.updateCoaAccount(event.id, event.data);
      emit(const CoaActionSuccess('Akun berhasil diperbarui'));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    } catch (e) {
      emit(CoaError(e.toString()));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    }
  }

  Future<void> _onDeleteCoaAccount(DeleteCoaAccount event, Emitter<CoaState> emit) async {
    emit(CoaLoading());
    try {
      await financeRepository.deleteCoaAccount(event.id);
      emit(const CoaActionSuccess('Akun berhasil dinonaktifkan'));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    } catch (e) {
      emit(CoaError(e.toString()));
      add(FetchCoaAccounts(includeInactive: _lastIncludeInactive, search: _lastSearch));
    }
  }
}
