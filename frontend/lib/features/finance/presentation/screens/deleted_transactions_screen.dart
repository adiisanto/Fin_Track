import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/transaction_history_bloc.dart';
import '../bloc/transaction_history_event.dart';
import '../bloc/transaction_history_state.dart';

class DeletedTransactionsScreen extends StatefulWidget {
  const DeletedTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<DeletedTransactionsScreen> createState() => _DeletedTransactionsScreenState();
}

class _DeletedTransactionsScreenState extends State<DeletedTransactionsScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    context.read<TransactionHistoryBloc>().add(DeletedTransactionsFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi Terhapus'),
      ),
      body: BlocBuilder<TransactionHistoryBloc, TransactionHistoryState>(
        builder: (context, state) {
          if (state is TransactionHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DeletedTransactionsLoaded) {
            final transactions = state.deletedTransactions;
            if (transactions.isEmpty) {
              return const Center(child: Text('Tidak ada riwayat transaksi terhapus.'));
            }

            return ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tx.type ?? 'Uncategorized',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              currencyFormat.format(tx.amountInBaseCurrency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.payment, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(tx.paymentMethodName ?? 'Unknown Method', style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('Transaksi: ${DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate.toLocal())}', style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text('Dihapus: ${DateFormat('yyyy-MM-dd HH:mm').format(tx.deletedAt.toLocal())}', style: TextStyle(color: Colors.red.shade700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(tx.processed ? Icons.check_circle : Icons.pending, size: 16, color: tx.processed ? Colors.blue : Colors.grey),
                            const SizedBox(width: 4),
                            Text(tx.processed ? 'Processed saat dihapus' : 'Unprocessed saat dihapus', style: TextStyle(color: tx.processed ? Colors.blue.shade700 : Colors.grey.shade700)),
                          ],
                        ),
                        if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(tx.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
                        ]
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (state is TransactionHistoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gagal memuat data: ${state.message}', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<TransactionHistoryBloc>().add(DeletedTransactionsFetchRequested()),
                    child: const Text('Coba Lagi'),
                  )
                ],
              ),
            );
          }
          return const Center(child: Text('Memuat...'));
        },
      ),
    );
  }
}
