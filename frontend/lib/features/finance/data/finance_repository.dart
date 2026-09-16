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

  Future<List<PaymentMethod>> getPaymentMethods({bool includeInactive = false}) async {
    try {
      final response = await dio.get('/api/v1/payment-methods', queryParameters: {'include_inactive': includeInactive});
      return (response.data['data'] as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load payment methods');
    }
  }

  Future<PaymentMethod> createPaymentMethod({
    required String code,
    required String name,
    String? fromAccount,
    bool isActive = true,
  }) async {
    try {
      final response = await dio.post('/api/v1/payment-methods', data: {
        'code': code,
        'name': name,
        'from_account': fromAccount,
        'is_active': isActive,
      });
      return PaymentMethod.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to create payment method');
    }
  }

  Future<PaymentMethod> updatePaymentMethod(String id, {
    String? code,
    String? name,
    String? fromAccount,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (code != null) data['code'] = code;
      if (name != null) data['name'] = name;
      if (fromAccount != null) data['from_account'] = fromAccount;
      if (isActive != null) data['is_active'] = isActive;

      final response = await dio.put('/api/v1/payment-methods/$id', data: data);
      return PaymentMethod.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to update payment method');
    }
  }

  Future<void> deletePaymentMethod(String id) async {
    try {
      await dio.delete('/api/v1/payment-methods/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to delete payment method');
    }
  }

  Future<List<PaymentMethod>> getPublicTemplates() async {
    try {
      final response = await dio.get('/api/v1/payment-methods/templates/public');
      return (response.data['data'] as List)
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to load public templates');
    }
  }

  Future<Map<String, dynamic>> previewTemplate(String templateId) async {
    try {
      final response = await dio.get('/api/v1/payment-methods/templates/$templateId/preview');
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to preview template');
    }
  }

  Future<PaymentMethod> copyTemplate(String templateId) async {
    try {
      final response = await dio.post('/api/v1/payment-methods/templates/$templateId/copy');
      return PaymentMethod.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to copy template');
    }
  }

  Future<List<MSTAccount>> lookupAccounts({String? q}) async {
    try {
      final queryParams = q != null ? {'q': q} : null;
      final response = await dio.get('/api/v1/accounts/lookup', queryParameters: queryParams);
      return (response.data['data'] as List)
          .map((json) => MSTAccount.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Failed to lookup accounts');
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
