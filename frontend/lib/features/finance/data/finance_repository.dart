import 'package:dio/dio.dart';
import '../domain/models.dart';

class FinanceRepository {
  final Dio dio;

  FinanceRepository({required this.dio});

  Future<DashboardSummary> getDashboardSummary({required String timeframe}) async {
    try {
      final response = await dio.get(
        '/api/v1/dashboard/summary',
        queryParameters: {'timeframe': timeframe},
      );
      return DashboardSummary.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load dashboard summary');
    }
  }

  Future<List<Currency>> getCurrencies({bool includeInactive = false}) async {
    try {
      final response = await dio.get('/api/v1/currencies', queryParameters: {'include_inactive': includeInactive});
      return (response.data['data'] as List)
          .map((json) => Currency.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load currencies');
    }
  }

  Future<Currency> addCurrency({
    required String code,
    required String name,
    required String symbol,
    bool isActive = true,
  }) async {
    try {
      final response = await dio.post('/api/v1/admin/currencies', data: {
        'code': code,
        'name': name,
        'symbol': symbol,
        'is_active': isActive,
      });
      return Currency.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to add currency');
    }
  }

  Future<void> deleteCurrency(String code) async {
    try {
      await dio.delete('/api/v1/admin/currencies/$code');
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to delete currency');
    }
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await dio.get('/api/v1/payment-methods');
      return (response.data['data'] as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load payment methods');
    }
  }

  Future<double> getLatestCurrencyRate(String fromCurrency, String toCurrency) async {
    try {
      final response = await dio.get(
        '/api/v1/currency-rates/latest',
        queryParameters: {
          'from_currency': fromCurrency,
          'to_currency': toCurrency,
        },
      );
      return (response.data['data']['rate'] as num).toDouble();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load currency rate');
    }
  }

  Future<void> createTransaction({
    required String type,
    required String currencyCode,
    required double amount,
    required String paymentMethodId,
    String? notes,
  }) async {
    try {
      await dio.post(
        '/api/v1/transactions',
        data: {
          'type': type,
          'currency_code': currencyCode,
          'amount': amount,
          'payment_method_id': paymentMethodId,
          'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to create transaction');
    }
  }
}
