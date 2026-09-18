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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'code': code,
      'name': name,
      'from_account': fromAccount,
      'account_description': accountDescription,
      'is_active': isActive,
      'is_template': isTemplate,
      'is_public': isPublic,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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

class Transaction {
  final String id;
  final String? type;
  final String currencyCode;
  final double amount;
  final double exchangeRate;
  final double amountInBaseCurrency;
  final PaymentMethod paymentMethod;
  final String? notes;
  final bool processed;
  final DateTime transactionDate;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    this.type,
    required this.currencyCode,
    required this.amount,
    required this.exchangeRate,
    required this.amountInBaseCurrency,
    required this.paymentMethod,
    this.notes,
    this.processed = false,
    required this.transactionDate,
    this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      type: json['type'],
      currencyCode: json['currency_code'],
      amount: (json['amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      amountInBaseCurrency: (json['amount_in_base_currency'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromJson(json['payment_method']),
      notes: json['notes'],
      processed: json['processed'] ?? false,
      transactionDate: DateTime.parse(json['transaction_date']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'currency_code': currencyCode,
      'amount': amount,
      'exchange_rate': exchangeRate,
      'amount_in_base_currency': amountInBaseCurrency,
      'payment_method': paymentMethod.toJson(),
      'notes': notes,
      'processed': processed,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }
}

class DeletedTransaction {
  final String id;
  final String originalTransactionId;
  final String userId;
  final String? type;
  final String currencyCode;
  final double amount;
  final double exchangeRate;
  final double amountInBaseCurrency;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? notes;
  final bool processed;
  final DateTime transactionDate;
  final DateTime originalCreatedAt;
  final DateTime originalUpdatedAt;
  final DateTime deletedAt;

  DeletedTransaction({
    required this.id,
    required this.originalTransactionId,
    required this.userId,
    this.type,
    required this.currencyCode,
    required this.amount,
    required this.exchangeRate,
    required this.amountInBaseCurrency,
    this.paymentMethodId,
    this.paymentMethodName,
    this.notes,
    this.processed = false,
    required this.transactionDate,
    required this.originalCreatedAt,
    required this.originalUpdatedAt,
    required this.deletedAt,
  });

  factory DeletedTransaction.fromJson(Map<String, dynamic> json) {
    return DeletedTransaction(
      id: json['id'],
      originalTransactionId: json['original_transaction_id'],
      userId: json['user_id'],
      type: json['type'],
      currencyCode: json['currency_code'],
      amount: (json['amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      amountInBaseCurrency: (json['amount_in_base_currency'] as num).toDouble(),
      paymentMethodId: json['payment_method_id'],
      paymentMethodName: json['payment_method_name'],
      notes: json['notes'],
      processed: json['processed'] ?? false,
      transactionDate: DateTime.parse(json['transaction_date']),
      originalCreatedAt: DateTime.parse(json['original_created_at']),
      originalUpdatedAt: DateTime.parse(json['original_updated_at']),
      deletedAt: DateTime.parse(json['deleted_at']),
    );
  }
}
