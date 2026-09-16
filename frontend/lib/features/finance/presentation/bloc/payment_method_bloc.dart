import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import 'payment_method_event.dart';
import 'payment_method_state.dart';

class PaymentMethodBloc extends Bloc<PaymentMethodEvent, PaymentMethodState> {
  final FinanceRepository repository;

  PaymentMethodBloc({required this.repository}) : super(PaymentMethodInitial()) {
    on<LoadPaymentMethods>(_onLoadPaymentMethods);
    on<CreatePaymentMethod>(_onCreatePaymentMethod);
    on<UpdatePaymentMethod>(_onUpdatePaymentMethod);
    on<DeletePaymentMethod>(_onDeletePaymentMethod);
    on<PreviewTemplate>(_onPreviewTemplate);
    on<CopyTemplate>(_onCopyTemplate);
  }

  Future<void> _onLoadPaymentMethods(
    LoadPaymentMethods event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodLoading());
    try {
      final paymentMethods = await repository.getPaymentMethods(includeInactive: true);
      final publicTemplates = await repository.getPublicTemplates();
      emit(PaymentMethodLoaded(
        paymentMethods: paymentMethods,
        publicTemplates: publicTemplates,
      ));
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }

  Future<void> _onCreatePaymentMethod(
    CreatePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodActionLoading());
    try {
      await repository.createPaymentMethod(
        code: event.code,
        name: event.name,
        fromAccount: event.fromAccount,
        isActive: event.isActive,
      );
      emit(const PaymentMethodActionSuccess("Metode pembayaran berhasil ditambahkan"));
      add(LoadPaymentMethods());
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }

  Future<void> _onUpdatePaymentMethod(
    UpdatePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodActionLoading());
    try {
      await repository.updatePaymentMethod(
        event.id,
        code: event.code,
        name: event.name,
        fromAccount: event.fromAccount,
        isActive: event.isActive,
      );
      emit(const PaymentMethodActionSuccess("Metode pembayaran berhasil diperbarui"));
      add(LoadPaymentMethods());
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }

  Future<void> _onDeletePaymentMethod(
    DeletePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodActionLoading());
    try {
      await repository.deletePaymentMethod(event.id);
      emit(const PaymentMethodActionSuccess("Metode pembayaran berhasil dinonaktifkan"));
      add(LoadPaymentMethods());
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }

  Future<void> _onPreviewTemplate(
    PreviewTemplate event,
    Emitter<PaymentMethodState> emit,
  ) async {
    // We might want to keep the current loaded list, so we could use a separate bloc or just yield and revert.
    // For simplicity, we emit ActionLoading, then PreviewLoaded.
    emit(PaymentMethodActionLoading());
    try {
      final previewData = await repository.previewTemplate(event.templateId);
      emit(TemplatePreviewLoaded(previewData));
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }

  Future<void> _onCopyTemplate(
    CopyTemplate event,
    Emitter<PaymentMethodState> emit,
  ) async {
    emit(PaymentMethodActionLoading());
    try {
      await repository.copyTemplate(event.templateId);
      emit(const PaymentMethodActionSuccess("Template berhasil disalin"));
      add(LoadPaymentMethods());
    } catch (e) {
      emit(PaymentMethodError(e.toString()));
    }
  }
}
