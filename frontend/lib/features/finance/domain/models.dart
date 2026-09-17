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

class MSTAccount {
  final String? id;
  final String account;
  final String description;
  final String type;
  final String? dimensi1;
  final String? dimensi2;
  final String? dimensi3;
  final String? dimensi4;
  final bool active;
  final DateTime? createdAt;
  final String? createdBy;
  final bool hasTransactions;

  MSTAccount({
    this.id,
    required this.account,
    required this.description,
    required this.type,
    this.dimensi1,
    this.dimensi2,
    this.dimensi3,
    this.dimensi4,
    required this.active,
    this.createdAt,
    this.createdBy,
    this.hasTransactions = false,
  });

  factory MSTAccount.fromJson(Map<String, dynamic> json) {
    return MSTAccount(
      id: json['id'],
      account: json['account'],
      description: json['description'],
      type: json['type'],
      dimensi1: json['dimensi1'],
      dimensi2: json['dimensi2'],
      dimensi3: json['dimensi3'],
      dimensi4: json['dimensi4'],
      active: json['active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      createdBy: json['created_by'],
      hasTransactions: json['has_transactions'] ?? false,
    );
  }
}

class PaymentMethod {
  final String id;
  final String? userId;
  final String code;
  final String name;
  final String? fromAccount;
  final String? accountDescription;
  final bool isActive;
  final bool isTemplate;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentMethod({
    required this.id,
    this.userId,
    required this.code,
    required this.name,
    this.fromAccount,
    this.accountDescription,
    this.isActive = true,
    this.isTemplate = false,
    this.isPublic = false,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      userId: json['user_id'],
      code: json['code'],
      name: json['name'],
      fromAccount: json['from_account'],
      accountDescription: json['account_description'],
      isActive: json['is_active'] ?? true,
      isTemplate: json['is_template'] ?? false,
      isPublic: json['is_public'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
