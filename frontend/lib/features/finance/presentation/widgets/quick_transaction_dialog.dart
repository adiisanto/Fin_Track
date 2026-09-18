import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models.dart';
import '../../data/finance_repository.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import 'payment_method_lookup_dialog.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class QuickTransactionDialog extends StatefulWidget {
  const QuickTransactionDialog({Key? key}) : super(key: key);

  @override
  State<QuickTransactionDialog> createState() => _QuickTransactionDialogState();
}

class _QuickTransactionDialogState extends State<QuickTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _typeController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCurrency;
  PaymentMethod? _selectedPaymentMethod;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  double _amountInBase = 0;
  double _currentRate = 1.0;
  bool _calculatingRate = false;

  late final String _baseCurrency;
  late final FinanceRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<FinanceRepository>();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _baseCurrency = authState.user.baseCurrency;
      _selectedCurrency = _baseCurrency;
    } else {
      _baseCurrency = 'IDR';
      _selectedCurrency = 'IDR';
    }
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    context.read<TransactionBloc>().add(TransactionFormDataRequested());
  }

  void _onAmountOrCurrencyChanged() async {
    final amountText = _amountController.text;
    final amount = double.tryParse(amountText) ?? 0;
    final curr = _selectedCurrency ?? _baseCurrency;

    if (amount > 0) {
      setState(() => _calculatingRate = true);
      try {
        final rate = await _repo.getLatestCurrencyRate(curr, _baseCurrency);
        if (!mounted) return;
        setState(() {
          _currentRate = rate;
          _amountInBase = amount * rate;
          _calculatingRate = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _calculatingRate = false);
      }
    } else {
      setState(() {
        _amountInBase = 0;
        _currentRate = 1.0;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final initialDate = _selectedDate ?? DateTime.now();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? TimeOfDay.now(),
      );
      if (time != null && mounted) {
        final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (combined.isAfter(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak boleh memilih waktu di masa depan.'), backgroundColor: Colors.red));
          setState(() {
            _selectedDate = DateTime.now();
            _selectedTime = TimeOfDay.now();
          });
        } else {
          setState(() {
            _selectedDate = date;
            _selectedTime = time;
          });
        }
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedPaymentMethod == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih metode pembayaran terlebih dahulu.'), backgroundColor: Colors.red));
        return;
      }
      final dt = _selectedDate != null && _selectedTime != null
          ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute)
          : null;
      
      String? t = _typeController.text.trim();
      if (t.isEmpty) t = null;

      context.read<TransactionBloc>().add(TransactionSubmitRequested(
        type: t,
        currencyCode: _selectedCurrency!,
        amount: double.parse(_amountController.text),
        paymentMethodId: _selectedPaymentMethod!.id,
        notes: _notesController.text,
        transactionDate: dt,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<TransactionBloc, TransactionState>(
          listener: (context, state) {
            if (state is TransactionSubmitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil dicatat.'), backgroundColor: Colors.green));
              Navigator.of(context).pop(true);
            } else if (state is TransactionError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          builder: (context, state) {
            if (state is TransactionFormDataLoading || state is TransactionInitial) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            List<Currency> currencies = [];
            if (state is TransactionFormDataLoaded) {
              currencies = state.currencies;
            } else {
              // Usually we might want to keep the loaded data if state changes to submitting
              // But for this simple dialog it is fine if we refetch or keep the selected ones.
              // Let's just fallback to selected currency.
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Catat Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _typeController,
                      decoration: const InputDecoration(labelText: 'Tipe Transaksi (Opsional)', hintText: 'Contoh: Makan, Gaji, dll.'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Mata Uang'),
                            value: _selectedCurrency,
                            items: currencies.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
                            onChanged: (val) {
                              setState(() => _selectedCurrency = val);
                              _onAmountOrCurrencyChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(labelText: 'Nominal'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _onAmountOrCurrencyChanged(),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Wajib diisi';
                              final amt = double.tryParse(val);
                              if (amt == null || amt <= 0) return 'Tidak valid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_calculatingRate)
                      const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.only(top: 4), child: Text('Menghitung kurs...', style: TextStyle(fontSize: 12, color: Colors.grey)))),
                    if (!_calculatingRate && _currentRate != 1.0)
                      Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('1 ${_selectedCurrency} = $_currentRate $_baseCurrency', style: const TextStyle(fontSize: 12, color: Colors.grey)))),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Total dalam $_baseCurrency',
                        fillColor: Colors.grey.shade200,
                        filled: true,
                      ),
                      controller: TextEditingController(text: _amountInBase.toStringAsFixed(2)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final method = await showDialog<PaymentMethod>(
                          context: context,
                          barrierDismissible: true,
                          builder: (ctx) => BlocProvider.value(
                            value: context.read<TransactionBloc>(), // not really needed for lookup but okay
                            child: const PaymentMethodLookupDialog(),
                          ),
                        );
                        if (method != null && mounted) {
                          setState(() => _selectedPaymentMethod = method);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Metode Pembayaran', suffixIcon: Icon(Icons.search)),
                        child: Text(_selectedPaymentMethod != null ? '${_selectedPaymentMethod!.name} (${_selectedPaymentMethod!.code})' : 'Pilih metode pembayaran'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDateTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Waktu Transaksi', suffixIcon: Icon(Icons.calendar_today)),
                        child: Text(_selectedDate != null && _selectedTime != null 
                          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')} ${_selectedTime!.hour.toString().padLeft(2,'0')}:${_selectedTime!.minute.toString().padLeft(2,'0')}'
                          : 'Pilih Waktu (Default: Sekarang)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Catatan (Opsional)'),
                      maxLines: 3,
                      minLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: state is TransactionSubmitting ? null : _submit,
                          child: state is TransactionSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
