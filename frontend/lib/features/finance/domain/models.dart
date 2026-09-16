class Currency {
  final String code;
  final String name;
  final String symbol;
  final bool isActive;
  final DateTime? createdAt;

  Currency({
    required this.code,
    required this.name,
    required this.symbol,
    this.isActive = true,
    this.createdAt,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'],
      name: json['name'],
      symbol: json['symbol'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class PaymentMethod {
  final String id;
  final String code;
  final String name;
  final String fromAccount;
  final String? accountDescription;

  PaymentMethod({
    required this.id,
    required this.code,
    required this.name,
    required this.fromAccount,
    this.accountDescription,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      fromAccount: json['from_account'],
      accountDescription: json['account_description'],
    );
  }
}

class DashboardSummary {
  final String baseCurrency;
  final String timeframe;
  final double totalIncome;
  final double totalExpense;
  final double netProfitLoss;
  final int totalTransactions;

  DashboardSummary({
    required this.baseCurrency,
    required this.timeframe,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfitLoss,
    required this.totalTransactions,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      baseCurrency: json['base_currency'],
      timeframe: json['timeframe'],
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpense: (json['total_expense'] as num).toDouble(),
      netProfitLoss: (json['net_profit_loss'] as num).toDouble(),
      totalTransactions: json['total_transactions'] as int,
    );
  }
}
