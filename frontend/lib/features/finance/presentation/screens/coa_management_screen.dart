import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import '../../domain/models.dart';
import '../bloc/coa_bloc.dart';

class CoaManagementScreen extends StatelessWidget {
  const CoaManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CoaBloc(
        financeRepository: context.read<FinanceRepository>(),
      )..add(const FetchCoaAccounts()),
      child: const _CoaManagementView(),
    );
  }
}

class _CoaManagementView extends StatefulWidget {
  const _CoaManagementView({Key? key}) : super(key: key);

  @override
  State<_CoaManagementView> createState() => _CoaManagementViewState();
}

class _CoaManagementViewState extends State<_CoaManagementView> {
  bool _includeInactive = false;
  final TextEditingController _searchController = TextEditingController();

  void _fetchAccounts() {
    context.read<CoaBloc>().add(FetchCoaAccounts(
          includeInactive: _includeInactive,
          search: _searchController.text,
        ));
  }

  void _showFormDialog({MSTAccount? account}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<CoaBloc>()),
        ],
        child: CoaFormDialog(account: account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen COA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAccounts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
      body: BlocListener<CoaBloc, CoaState>(
        listener: (context, state) {
          if (state is CoaActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is CoaError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Cari akun / deskripsi...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _fetchAccounts(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _includeInactive,
                        onChanged: (val) {
                          setState(() => _includeInactive = val ?? false);
                          _fetchAccounts();
                        },
                      ),
                      const Text('Tampilkan Nonaktif'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<CoaBloc, CoaState>(
                builder: (context, state) {
                  if (state is CoaLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is CoaLoaded) {
                    if (state.accounts.isEmpty) {
                      return const Center(child: Text('Tidak ada data akun.'));
                    }
                    return ListView.builder(
                      itemCount: state.accounts.length,
                      itemBuilder: (context, index) {
                        final acc = state.accounts[index];
                        final isDebit = acc.type.toLowerCase() == 'debit';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          color: acc.active ? Colors.white : Colors.grey[200],
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDebit ? Colors.green[100] : Colors.red[100],
                              child: Icon(
                                isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isDebit ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text('${acc.account} - ${acc.description}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tipe: ${acc.type}'),
                                if (acc.dimensi1 != null) Text('Dimensi 1: ${acc.dimensi1}'),
                                if (acc.hasTransactions)
                                  const Text('Terhubung transaksi', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                if (acc.active)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Nonaktifkan (Soft Delete)', style: TextStyle(color: Colors.red)),
                                  ),
                              ],
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showFormDialog(account: acc);
                                } else if (val == 'delete') {
                                  if (acc.hasTransactions) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun sudah memiliki transaksi, tidak dapat dihapus.'), backgroundColor: Colors.red));
                                    return;
                                  }
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Konfirmasi'),
                                      content: Text('Nonaktifkan akun ${acc.account}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            context.read<CoaBloc>().add(DeleteCoaAccount(acc.id!));
                                            Navigator.pop(c);
                                          },
                                          child: const Text('Nonaktifkan'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  } else if (state is CoaError) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoaFormDialog extends StatefulWidget {
  final MSTAccount? account;
  const CoaFormDialog({Key? key, this.account}) : super(key: key);

  @override
  State<CoaFormDialog> createState() => _CoaFormDialogState();
}

class _CoaFormDialogState extends State<CoaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountController;
  late TextEditingController _descController;
  String _type = 'Debit';
  bool _active = true;
  String? _dim1;
  String? _dim2;
  String? _dim3;
  String? _dim4;
  
  bool get isEdit => widget.account != null;
  bool get hasTransactions => widget.account?.hasTransactions ?? false;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.account?.account);
    _descController = TextEditingController(text: widget.account?.description);
    if (widget.account != null) {
      _type = widget.account!.type;
      _active = widget.account!.active;
      _dim1 = widget.account!.dimensi1;
      _dim2 = widget.account!.dimensi2;
      _dim3 = widget.account!.dimensi3;
      _dim4 = widget.account!.dimensi4;
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'account': _accountController.text.trim(),
        'description': _descController.text.trim(),
        'type': _type,
        'dimensi1': _dim1,
        'dimensi2': _dim2,
        'dimensi3': _dim3,
        'dimensi4': _dim4,
        'active': _active,
      };

      if (isEdit) {
        context.read<CoaBloc>().add(UpdateCoaAccount(widget.account!.id!, data));
      } else {
        context.read<CoaBloc>().add(CreateCoaAccount(data));
      }
      Navigator.pop(context);
    }
  }

  void _showLookup(int dimIndex) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const CoaLookupDialog(),
    );
    if (result != null) {
      setState(() {
        if (dimIndex == 1) _dim1 = result;
        if (dimIndex == 2) _dim2 = result;
        if (dimIndex == 3) _dim3 = result;
        if (dimIndex == 4) _dim4 = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? 'Edit COA' : 'Tambah COA'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTransactions)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.orange[100],
                  child: const Text('Akun ini telah digunakan dalam transaksi. Kode dan Tipe Akun tidak dapat diubah.', style: TextStyle(color: Colors.orange)),
                ),
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(labelText: 'Kode Akun'),
                readOnly: isEdit && hasTransactions,
                validator: (v) => v == null || v.isEmpty ? 'Kode harus diisi' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                validator: (v) => v == null || v.isEmpty ? 'Deskripsi harus diisi' : null,
              ),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipe'),
                items: const [
                  DropdownMenuItem(value: 'Debit', child: Text('Debit')),
                  DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                ],
                onChanged: (isEdit && hasTransactions) ? null : (v) => setState(() => _type = v!),
              ),
              ...[1, 2, 3, 4].map((i) {
                String? currentVal = i == 1 ? _dim1 : i == 2 ? _dim2 : i == 3 ? _dim3 : _dim4;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Dimensi $i: ${currentVal ?? "Tidak ada"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _showLookup(i),
                  ),
                );
              }).toList(),
              SwitchListTile(
                title: const Text('Aktif'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (widget.account?.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Dibuat: ${widget.account!.createdAt!.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class CoaLookupDialog extends StatefulWidget {
  const CoaLookupDialog({Key? key}) : super(key: key);

  @override
  State<CoaLookupDialog> createState() => _CoaLookupDialogState();
}

class _CoaLookupDialogState extends State<CoaLookupDialog> {
  late final FinanceRepository repo;
  List<MSTAccount> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    repo = context.read<FinanceRepository>();
    _load('');
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final res = await repo.getCoaAccounts(includeInactive: false, search: q);
      setState(() {
        _accounts = res;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Akun'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari akun...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _load,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _accounts.length,
                      itemBuilder: (ctx, i) {
                        final acc = _accounts[i];
                        return ListTile(
                          title: Text('${acc.account} - ${acc.description}'),
                          onTap: () => Navigator.pop(context, acc.account),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
      ],
    );
  }
}
