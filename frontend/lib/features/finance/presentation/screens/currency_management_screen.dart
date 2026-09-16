import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../bloc/currency_bloc.dart';
import '../../domain/models.dart';

class CurrencyManagementScreen extends StatefulWidget {
  const CurrencyManagementScreen({Key? key}) : super(key: key);

  @override
  State<CurrencyManagementScreen> createState() => _CurrencyManagementScreenState();
}

class _CurrencyManagementScreenState extends State<CurrencyManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CurrencyBloc>().add(CurrencyFetchRequested());
  }

  void _showAddCurrencyDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final symbolController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Mata Uang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Kode (Maks 3 Huruf)'),
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: symbolController,
              decoration: const InputDecoration(labelText: 'Simbol'),
              maxLength: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeController.text.isNotEmpty && nameController.text.isNotEmpty && symbolController.text.isNotEmpty) {
                context.read<CurrencyBloc>().add(
                  CurrencyCreateRequested(
                    code: codeController.text,
                    name: nameController.text,
                    symbol: symbolController.text,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $code?'),
        content: Text('Apakah Anda yakin ingin menghapus mata uang $code? Semua data kurs terkait juga akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<CurrencyBloc>().add(CurrencyDeleteRequested(code));
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PROTEKSI HALAMAN
    final authState = context.watch<AuthBloc>().state;
    if (authState is Authenticated && !authState.user.isSuperuser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const Center(child: Text('Halaman ini hanya untuk Superadmin.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Mata Uang'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCurrencyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Mata Uang'),
      ),
      body: BlocConsumer<CurrencyBloc, CurrencyState>(
        listener: (context, state) {
          if (state is CurrencyOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state is CurrencyError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is CurrencyLoading || state is CurrencyInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CurrencyLoaded) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kode')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Simbol')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Dibuat (UTC)')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: state.currencies.map((currency) {
                  return DataRow(cells: [
                    DataCell(Text(currency.code)),
                    DataCell(Text(currency.name)),
                    DataCell(Text(currency.symbol)),
                    DataCell(Text(currency.isActive ? 'Aktif' : 'Nonaktif')),
                    DataCell(Text(currency.createdAt?.toString().split('.').first ?? '-')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmDialog(currency.code),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            );
          } else if (state is CurrencyError) {
            // Error is handled in listener but might need a retry button
            return Center(child: Text('Error loading currencies.'));
          }
          // Default fallback
          final blocState = context.read<CurrencyBloc>().state;
          if (blocState is CurrencyLoaded) {
            // Keep showing data when dialog succeeds
             return Container();
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
