import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = typeExpense; // expense | income | transfer

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    Widget list;
    if (_filter == 'transfer') {
      list = s.transfers.isEmpty
          ? const EmptyState('Belum ada transfer bulan ini.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: s.transfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _transferTile(context, s, s.transfers[i]),
            );
    } else {
      final items = _filter == typeExpense ? s.expenses : s.incomes;
      list = items.isEmpty
          ? const EmptyState('Belum ada transaksi bulan ini.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _txTile(context, s, items[i], cs),
            );
    }

    return Column(
      children: [
        const MonthSelector(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: typeExpense, label: Text('Keluar')),
                ButtonSegment(value: typeIncome, label: Text('Masuk')),
                ButtonSegment(value: 'transfer', label: Text('Transfer')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _txTile(BuildContext context, AppState s, TxModel t, ColorScheme cs) {
    final isIncome = t.type == typeIncome;
    final color = isIncome ? Colors.green.shade600 : cs.error;
    final locked = t.transferId != null; // biaya admin: hapus lewat transfer
    final subtitle = [
      if (t.note.isNotEmpty) t.note,
      s.accountName(t.accountId),
      dateLabel(parseIso(t.date)),
    ].join(' · ');

    final tile = Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(isIncome ? Icons.north_east : Icons.south_west, color: color, size: 20),
        ),
        title: Text(t.category),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${isIncome ? '+' : '-'}${rupiah(t.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('tx${t.id}'),
      direction: locked ? DismissDirection.none : DismissDirection.endToStart,
      background: _deleteBg(cs),
      confirmDismiss: (_) => confirm(context, 'Hapus transaksi?',
          '${t.category} ${rupiah(t.amount)} akan dihapus.',
          ok: 'Hapus'),
      onDismissed: (_) => context.read<AppState>().removeTransaction(t.id!),
      child: tile,
    );
  }

  Widget _transferTile(BuildContext context, AppState s, TransferModel t) {
    final cs = Theme.of(context).colorScheme;
    final sub = [
      if (t.adminFee > 0) 'Admin ${rupiah(t.adminFee)}',
      if (t.note.isNotEmpty) t.note,
      dateLabel(parseIso(t.date)),
    ].join(' · ');
    return Dismissible(
      key: ValueKey('tr${t.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteBg(cs),
      confirmDismiss: (_) => confirm(context, 'Hapus transfer?',
          'Biaya admin terkait (jika ada) ikut dihapus.',
          ok: 'Hapus'),
      onDismissed: (_) => context.read<AppState>().removeTransfer(t.id!),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primary.withOpacity(0.12),
            child: Icon(Icons.swap_horiz, color: cs.primary, size: 20),
          ),
          title: Text('${s.accountName(t.fromAccountId)} → ${s.accountName(t.toAccountId)}'),
          subtitle: Text(sub),
          trailing: Text(rupiah(t.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _deleteBg(ColorScheme cs) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      );
}
