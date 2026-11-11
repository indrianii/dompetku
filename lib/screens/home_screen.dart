import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/constants.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'dashboard_screen.dart';
import 'receivables_screen.dart';
import 'settings_screen.dart';
import 'split_bill_screen.dart';
import 'transactions_screen.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Ringkasan', 'Transaksi', 'Piutang', 'Akun'];
  static const _pages = <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    ReceivablesScreen(),
    AccountsScreen(),
  ];

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.south_west),
              title: const Text('Pengeluaran'),
              onTap: () {
                Navigator.pop(c);
                _open(const AddTransactionScreen(type: typeExpense));
              },
            ),
            ListTile(
              leading: const Icon(Icons.north_east),
              title: const Text('Pemasukan'),
              onTap: () {
                Navigator.pop(c);
                _open(const AddTransactionScreen(type: typeIncome));
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfer / Top-Up'),
              onTap: () {
                Navigator.pop(c);
                _open(const TransferScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Split Bill / Talangan'),
              onTap: () {
                Navigator.pop(c);
                _open(const SplitBillScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AppState, bool>((s) => s.loading);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Export & Backup',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => _open(const SettingsScreen()),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Ringkasan'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Piutang'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Akun'),
        ],
      ),
    );
  }
}
