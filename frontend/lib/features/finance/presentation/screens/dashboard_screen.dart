import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../bloc/transaction_bloc.dart';
import '../../data/finance_repository.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTimeframe = 'monthly';

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  void _fetchDashboard() {
    context.read<DashboardBloc>().add(DashboardFetchRequested(_selectedTimeframe));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    String userName = "User";
    String baseCurrency = "IDR";
    
    if (authState is Authenticated) {
      userName = authState.user.fullName;
      baseCurrency = authState.user.baseCurrency;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, $userName'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(baseCurrency, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildTimeframeSelector(),
          Expanded(
            child: BlocBuilder<DashboardBloc, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading || state is DashboardInitial) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is DashboardError) {
                  return Center(child: Text('Error: ${state.message}'));
                } else if (state is DashboardLoaded) {
                  return _buildSummaryCards(state.summary);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to add expense screen and wait for result
          final shouldRefresh = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (ctx) => TransactionBloc(
                  financeRepository: context.read<FinanceRepository>(),
                ),
                child: const AddExpenseScreen(),
              ),
            ),
          );

          if (shouldRefresh == true) {
            _fetchDashboard();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Catat Pengeluaran'),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'daily', label: Text('Harian')),
          ButtonSegment(value: 'weekly', label: Text('Mingguan')),
          ButtonSegment(value: 'monthly', label: Text('Bulanan')),
          ButtonSegment(value: 'lifetime', label: Text('Lifetime')),
        ],
        selected: {_selectedTimeframe},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedTimeframe = newSelection.first;
          });
          _fetchDashboard();
        },
      ),
    );
  }

  Widget _buildSummaryCards(summary) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard('Pemasukan', summary.totalIncome, Colors.green),
        const SizedBox(height: 16),
        _buildCard('Pengeluaran', summary.totalExpense, Colors.red),
        const SizedBox(height: 16),
        _buildCard('Untung / Rugi', summary.netProfitLoss, summary.netProfitLoss >= 0 ? Colors.green : Colors.red),
      ],
    );
  }

  Widget _buildCard(String title, double amount, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
