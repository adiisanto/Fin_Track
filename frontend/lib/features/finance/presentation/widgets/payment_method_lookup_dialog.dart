import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/finance_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PaymentMethodLookupDialog extends StatefulWidget {
  const PaymentMethodLookupDialog({Key? key}) : super(key: key);

  @override
  State<PaymentMethodLookupDialog> createState() => _PaymentMethodLookupDialogState();
}

class _PaymentMethodLookupDialogState extends State<PaymentMethodLookupDialog> {
  late final FinanceRepository repo;
  List<PaymentMethod> _methods = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    repo = context.read<FinanceRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final methods = await repo.getPaymentMethods(includeInactive: false);
      if (!mounted) return;
      setState(() {
        _methods = methods.where((m) {
          final q = _search.toLowerCase();
          return m.code.toLowerCase().contains(q) || m.name.toLowerCase().contains(q);
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari Kode / Nama',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                _search = val;
                _load();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _methods.isEmpty
                      ? const Center(child: Text('Tidak ada metode pembayaran ditemukan.'))
                      : ListView.builder(
                          itemCount: _methods.length,
                          itemBuilder: (ctx, i) {
                            final m = _methods[i];
                            return ListTile(
                              leading: const Icon(Icons.payment),
                              title: Text(m.name),
                              subtitle: Text(m.code),
                              onTap: () {
                                Navigator.of(context).pop(m);
                              },
                            );
                          },
                        ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
