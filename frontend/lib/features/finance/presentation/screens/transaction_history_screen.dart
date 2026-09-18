import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/models.dart';
import '../bloc/transaction_history_bloc.dart';
import '../bloc/transaction_history_event.dart';
import '../bloc/transaction_history_state.dart';
import '../widgets/edit_transaction_dialog.dart';
import 'deleted_transactions_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  DateTime? _startDate;
  DateTime? _endDate;
  final _typeController = TextEditingController();
  final _notesController = TextEditingController();
  String? _paymentMethodId; // Simplified: we could use PaymentMethodLookupDialog for this

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    context.read<TransactionHistoryBloc>().add(TransactionHistoryFetchRequested(
      startDate: _startDate,
      endDate: _endDate,
      type: _typeController.text.isNotEmpty ? _typeController.text : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      paymentMethodId: _paymentMethodId,
    ));
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _typeController.clear();
      _notesController.clear();
      _paymentMethodId = null;
    });
    _fetchData();
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _showDeleteConfirmation(Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini? Data yang dihapus akan dipindahkan ke riwayat transaksi terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TransactionHistoryBloc>().add(TransactionHistoryDeleteRequested(tx.id));
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Lihat Transaksi Terhapus',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => BlocProvider.value(
                    value: context.read<TransactionHistoryBloc>(),
                    child: const DeletedTransactionsScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocListener<TransactionHistoryBloc, TransactionHistoryState>(
        listener: (context, state) {
          if (state is TransactionHistoryOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
            _fetchData(); // Refresh list
          } else if (state is TransactionHistoryError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: Column(
          children: [
            // Filters Panel
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_startDate != null && _endDate != null
                              ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                              : 'Filter Tanggal'),
                          onPressed: _selectDateRange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Tipe',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Cari Catatan',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _fetchData, child: const Text('Cari')),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _resetFilters, child: const Text('Reset')),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: BlocBuilder<TransactionHistoryBloc, TransactionHistoryState>(
                buildWhen: (previous, current) => current is TransactionHistoryLoading || current is TransactionHistoryLoaded,
                builder: (context, state) {
                  if (state is TransactionHistoryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is TransactionHistoryLoaded) {
                    final transactions = state.transactions;
                    if (transactions.isEmpty) {
                      return const Center(child: Text('Tidak ada transaksi ditemukan.'));
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
                                    Text('${tx.paymentMethod.name} (${tx.paymentMethod.code})', style: TextStyle(color: Colors.grey.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate.toLocal()), style: TextStyle(color: Colors.grey.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: tx.processed,
                                          onChanged: null, // read-only
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Text(
                                          tx.processed ? 'Processed' : 'Unprocessed',
                                          style: TextStyle(
                                            color: tx.processed ? Colors.blue : Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final updated = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => BlocProvider.value(
                                                value: context.read<TransactionHistoryBloc>(),
                                                child: EditTransactionDialog(transaction: tx),
                                              ),
                                            );
                                            if (updated == true) {
                                              _fetchData();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete, color: tx.processed ? Colors.grey : Colors.red),
                                          tooltip: tx.processed ? 'Tidak dapat menghapus transaksi yang sudah diproses' : 'Hapus',
                                          onPressed: tx.processed ? null : () => _showDeleteConfirmation(tx),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                                  const Divider(),
                                  Text(tx.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: Text('Memuat...'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
