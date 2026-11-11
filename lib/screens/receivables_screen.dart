import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  bool _showSettled = false;

  Future<void> _settle(Receivable r) async {
    final s = context.read<AppState>();
    int? accId = s.accounts.isNotEmpty ? s.accounts.first.id : null;
    DateTime date = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setL) => AlertDialog(
          title: Text('Tandai lunas: ${r.person}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${rupiah(r.amount)} masuk ke saldo akun, tanpa dicatat sebagai Pemasukan.'),
              const SizedBox(height: 16),
              AccountDropdown(
                accounts: s.accounts,
                value: accId,
                label: 'Diterima di akun',
                onChanged: (v) => setL(() => accId = v),
              ),
              const SizedBox(height: 12),
              DateField(value: date, onChanged: (d) => setL(() => date = d), label: 'Tanggal dibayar'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lunas')),
          ],
        ),
      ),
    );
    if (ok == true && accId != null) {
      await s.settle(r.id!, accId!, isoDate(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = s.receivables.where((r) => r.settled == _showSettled).toList();

    final perPerson = <String, int>{};
    for (final r in s.receivables.where((r) => !r.settled)) {
      perPerson[r.person] = (perPerson[r.person] ?? 0) + r.amount;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          color: cs.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total piutang belum lunas', style: tt.labelLarge),
                const SizedBox(height: 4),
                Text(rupiah(s.outstanding),
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (perPerson.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final e in perPerson.entries)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${e.key}: ${rupiah(e.value)}'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Belum Lunas')),
            ButtonSegment(value: true, label: Text('Lunas')),
          ],
          selected: {_showSettled},
          onSelectionChanged: (v) => setState(() => _showSettled = v.first),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const SizedBox(height: 160, child: EmptyState('Tidak ada data.'))
        else
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.person,
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Text(rupiah(r.amount),
                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              final st = context.read<AppState>();
                              if (v == 'undo') {
                                await st.unsettle(r.id!);
                              } else if (v == 'delete') {
                                if (await confirm(context, 'Hapus piutang?',
                                    'Saldo akun penalang tidak otomatis dikembalikan.',
                                    ok: 'Hapus')) {
                                  await st.removeReceivable(r.id!);
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              if (r.settled)
                                const PopupMenuItem(value: 'undo', child: Text('Batalkan lunas')),
                              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        [
                          if (r.note.isNotEmpty) r.note,
                          'Ditalangi ${s.accountName(r.sourceAccountId)}',
                          dateLabel(parseIso(r.date)),
                        ].join(' · '),
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                      const SizedBox(height: 8),
                      if (r.settled)
                        Row(children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lunas ${dateLabel(parseIso(r.settledDate!))} ke ${s.accountName(r.settledAccountId)}',
                              style: tt.bodySmall,
                            ),
                          ),
                        ])
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () => _settle(r),
                            child: const Text('Tandai Lunas'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
