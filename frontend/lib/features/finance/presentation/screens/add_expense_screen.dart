import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCurrency;
  String? _selectedPaymentMethod;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  double _calculatedAmount = 0.0;
  List<Currency> _currencies = [];
  List<PaymentMethod> _methods = [];

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(TransactionFormDataRequested());
    
    // Set default currency from auth state
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _selectedCurrency = authState.user.baseCurrency;
    }
  }

  void _calculateRate() {
    if (_amountController.text.isEmpty || _selectedCurrency == null) return;
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<TransactionBloc>().add(
        TransactionRateRequested(
          _selectedCurrency!,
          authState.user.baseCurrency,
          amount,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Pengeluaran')),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaksi pengeluaran berhasil disimpan.')),
            );
            Navigator.pop(context, true); // Return true to signal refresh
          } else if (state is TransactionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is TransactionRateCalculated) {
            setState(() {
              _calculatedAmount = state.convertedAmount;
            });
          } else if (state is TransactionFormDataLoaded) {
            setState(() {
              _currencies = state.currencies;
              _methods = state.paymentMethods;
              // Check if selected currency is in the list
              if (_currencies.where((c) => c.code == _selectedCurrency).isEmpty && _currencies.isNotEmpty) {
                _selectedCurrency = _currencies.first.code;
              }
            });
          }
        },
        builder: (context, state) {
          if (state is TransactionFormDataLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Mata Uang'),
                    items: _currencies.map((Currency c) {
                      return DropdownMenuItem<String>(
                        value: c.code,
                        child: Text('${c.code} - ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCurrency = val;
                      });
                      _calculateRate();
                    },
                    validator: (val) => val == null ? 'Pilih mata uang' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Nominal'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => _calculateRate(),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Masukkan nominal';
                      final numVal = double.tryParse(val);
                      if (numVal == null || numVal <= 0) return 'Nominal tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estimasi dlm Base Currency: ${_calculatedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
                    items: _methods.map((PaymentMethod pm) {
                      return DropdownMenuItem<String>(
                        value: pm.id,
                        child: Text('${pm.name} (${pm.accountDescription ?? ""})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPaymentMethod = val;
                      });
                    },
                    validator: (val) => val == null ? 'Pilih metode pembayaran' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: state is TransactionSubmitting
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                context.read<TransactionBloc>().add(
                                  TransactionSubmitRequested(
                                    type: 'EXPENSE',
                                    currencyCode: _selectedCurrency!,
                                    amount: double.parse(_amountController.text),
                                    paymentMethodId: _selectedPaymentMethod!,
                                    notes: _notesController.text,
                                  ),
                                );
                              }
                            },
                      child: state is TransactionSubmitting
                          ? const CircularProgressIndicator()
                          : const Text('Simpan Transaksi'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
