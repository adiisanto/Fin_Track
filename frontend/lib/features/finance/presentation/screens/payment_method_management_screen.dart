import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/finance_repository.dart';
import '../bloc/payment_method_bloc.dart';
import '../bloc/payment_method_event.dart';
import '../bloc/payment_method_state.dart';
import '../../domain/models.dart';

class PaymentMethodManagementScreen extends StatelessWidget {
  const PaymentMethodManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentMethodBloc(
        repository: context.read<FinanceRepository>(),
      )..add(LoadPaymentMethods()),
      child: const PaymentMethodView(),
    );
  }
}

class PaymentMethodView extends StatelessWidget {
  const PaymentMethodView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Metode Pembayaran'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Metode Pembayaran Saya'),
              Tab(text: 'Template Publik'),
            ],
          ),
        ),
        body: BlocConsumer<PaymentMethodBloc, PaymentMethodState>(
          listener: (context, state) {
            if (state is PaymentMethodActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.green),
              );
            } else if (state is PaymentMethodError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            } else if (state is TemplatePreviewLoaded) {
              _showTemplatePreviewDialog(context, state.previewData);
            }
          },
          builder: (context, state) {
            if (state is PaymentMethodLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            List<PaymentMethod> myMethods = [];
            List<PaymentMethod> publicTemplates = [];

            if (state is PaymentMethodLoaded) {
              myMethods = state.paymentMethods;
              publicTemplates = state.publicTemplates;
            } else {
              // Retain state logic for when ActionLoading happens
              final bloc = context.read<PaymentMethodBloc>();
              if (bloc.state is PaymentMethodLoaded) {
                myMethods = (bloc.state as PaymentMethodLoaded).paymentMethods;
                publicTemplates = (bloc.state as PaymentMethodLoaded).publicTemplates;
              }
            }

            return TabBarView(
              children: [
                _buildMyMethodsTab(context, myMethods),
                _buildPublicTemplatesTab(context, publicTemplates),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () => _showPaymentMethodDialog(context),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildMyMethodsTab(BuildContext context, List<PaymentMethod> methods) {
    return ListView.builder(
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final pm = methods[index];
        return ListTile(
          title: Text(pm.name),
          subtitle: Text('${pm.code} - ${pm.accountDescription ?? "Tidak ada akun"}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: pm.isActive,
                onChanged: (val) {
                  context.read<PaymentMethodBloc>().add(
                    UpdatePaymentMethod(id: pm.id, isActive: val)
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showPaymentMethodDialog(context, paymentMethod: pm),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, pm),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublicTemplatesTab(BuildContext context, List<PaymentMethod> templates) {
    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final tmpl = templates[index];
        return ListTile(
          title: Text(tmpl.name),
          subtitle: Text(tmpl.code),
          trailing: ElevatedButton(
            onPressed: () {
              context.read<PaymentMethodBloc>().add(PreviewTemplate(tmpl.id));
            },
            child: const Text('Gunakan'),
          ),
        );
      },
    );
  }

  void _showPaymentMethodDialog(BuildContext context, {PaymentMethod? paymentMethod}) {
    final bloc = context.read<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (ctx) {
        return BlocProvider.value(
          value: bloc,
          child: PaymentMethodFormDialog(paymentMethod: paymentMethod),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, PaymentMethod pm) {
    final bloc = context.read<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Metode Pembayaran'),
        content: Text('Apakah Anda yakin ingin menonaktifkan ${pm.name}? Transaksi lama tidak akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              bloc.add(DeletePaymentMethod(pm.id));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showTemplatePreviewDialog(BuildContext context, Map<String, dynamic> previewData) {
    final bloc = context.read<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (ctx) {
        final bool isConflict = previewData['is_code_conflict'] ?? false;
        final String? conflictMsg = previewData['conflict_message'];
        final String templateId = previewData['id'];

        return AlertDialog(
          title: const Text('Pratinjau Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama: ${previewData["name"]}'),
              Text('Kode: ${previewData["code"]}'),
              if (previewData["account_description"] != null)
                Text('Akun: ${previewData["account_description"]}'),
              if (isConflict) ...[
                const SizedBox(height: 16),
                Text(
                  conflictMsg ?? 'Terdapat konflik kode.',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                bloc.add(LoadPaymentMethods()); // reload original list
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                bloc.add(CopyTemplate(templateId));
                Navigator.pop(ctx);
              },
              child: const Text('Salin & Gunakan'),
            ),
          ],
        );
      },
    ).then((_) {
      if (bloc.state is TemplatePreviewLoaded) {
        bloc.add(LoadPaymentMethods());
      }
    });
  }
}

class PaymentMethodFormDialog extends StatefulWidget {
  final PaymentMethod? paymentMethod;

  const PaymentMethodFormDialog({super.key, this.paymentMethod});

  @override
  State<PaymentMethodFormDialog> createState() => _PaymentMethodFormDialogState();
}

class _PaymentMethodFormDialogState extends State<PaymentMethodFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  String? _selectedAccount;
  String? _selectedAccountDesc;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.paymentMethod?.code ?? '');
    _nameController = TextEditingController(text: widget.paymentMethod?.name ?? '');
    _selectedAccount = widget.paymentMethod?.fromAccount;
    _selectedAccountDesc = widget.paymentMethod?.accountDescription;
    _isActive = widget.paymentMethod?.isActive ?? true;
  }

  Future<void> _selectAccount() async {
    final repo = context.read<FinanceRepository>();
    final account = await showDialog<MSTAccount>(
      context: context,
      builder: (ctx) => AccountLookupDialog(repository: repo),
    );
    if (account != null) {
      setState(() {
        _selectedAccount = account.account;
        _selectedAccountDesc = account.description;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (widget.paymentMethod == null) {
        context.read<PaymentMethodBloc>().add(CreatePaymentMethod(
          code: _codeController.text,
          name: _nameController.text,
          fromAccount: _selectedAccount,
          isActive: _isActive,
        ));
      } else {
        context.read<PaymentMethodBloc>().add(UpdatePaymentMethod(
          id: widget.paymentMethod!.id,
          code: _codeController.text,
          name: _nameController.text,
          fromAccount: _selectedAccount,
          isActive: _isActive,
        ));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.paymentMethod == null ? 'Tambah Metode' : 'Edit Metode'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Kode'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedAccountDesc != null 
                        ? 'Akun: $_selectedAccountDesc ($_selectedAccount)' 
                        : 'Belum memilih akun GL',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _selectAccount,
                  ),
                  if (_selectedAccount != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedAccount = null;
                          _selectedAccountDesc = null;
                        });
                      },
                    )
                ],
              ),
              SwitchListTile(
                title: const Text('Aktif'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
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

class AccountLookupDialog extends StatefulWidget {
  final FinanceRepository repository;
  const AccountLookupDialog({super.key, required this.repository});

  @override
  State<AccountLookupDialog> createState() => _AccountLookupDialogState();
}

class _AccountLookupDialogState extends State<AccountLookupDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<MSTAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts([String? q]) async {
    setState(() => _isLoading = true);
    try {
      final accs = await widget.repository.lookupAccounts(q: q);
      setState(() {
        _accounts = accs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari Akun GL'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Pencarian',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _loadAccounts(_searchController.text),
                ),
              ),
              onSubmitted: (val) => _loadAccounts(val),
            ),
            const SizedBox(height: 10),
            _isLoading 
              ? const CircularProgressIndicator()
              : Expanded(
                  child: ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (ctx, i) {
                      final acc = _accounts[i];
                      return ListTile(
                        title: Text(acc.description),
                        subtitle: Text(acc.account),
                        onTap: () => Navigator.pop(context, acc),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
