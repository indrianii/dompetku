import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sum = s.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Saldo',
                    style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer)),
                const SizedBox(height: 4),
                Text(rupiah(s.totalBalance),
                    style: tt.headlineMedium?.copyWith(
                        color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
                if (s.outstanding > 0) ...[
                  const SizedBox(height: 8),
                  Text('Piutang belum lunas: ${rupiah(s.outstanding)}',
                      style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const MonthSelector(),
        Row(
          children: [
            Expanded(child: _StatCard('Pemasukan', sum.income, Icons.north_east, Colors.green.shade600)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Pengeluaran', sum.expense, Icons.south_west, cs.error)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Selisih bulan ini'),
            trailing: Text(rupiah(sum.net),
                style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: sum.net >= 0 ? Colors.green.shade600 : cs.error)),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text('Transfer antar akun tidak dihitung di sini.',
              style: tt.bodySmall?.copyWith(color: cs.outline)),
        ),
        const SizedBox(height: 12),
        Text('Pengeluaran per kategori', style: tt.titleMedium),
        const SizedBox(height: 8),
        if (sum.expenseByCategory.isEmpty)
          const SizedBox(height: 80, child: EmptyState('Belum ada pengeluaran bulan ini.'))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final e in sum.expenseByCategory.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text(e.key), Text(rupiah(e.value))],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: sum.expense == 0 ? 0 : e.value / sum.expense,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: tt.labelLarge),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(rupiah(value),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
