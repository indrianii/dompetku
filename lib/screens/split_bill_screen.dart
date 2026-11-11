import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class _Person {
  final name = TextEditingController();
  final amount = TextEditingController();
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _form = GlobalKey<FormState>();
  final _total = TextEditingController();
  final _personal = TextEditingController();
  final _note = TextEditingController();
  final List<_Person> _people = [_Person()];
  DateTime _date = DateTime.now();
  String _category = expenseCategories.first;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final accs = context.read<AppState>().accounts;
    if (accs.isNotEmpty) _accountId = accs.first.id;
  }

  @override
  void dispose() {
    _total.dispose();
    _personal.dispose();
    _note.dispose();
    for (final p in _people) {
      p.dispose();
    }
    super.dispose();
  }

  int get _sharesSum => _people.fold(0, (s, p) => s + parseAmount(p.amount.text));

  int get _diff => parseAmount(_total.text) - parseAmount(_personal.text) - _sharesSum;

  /// Bagi rata total ke saya + semua teman; sisa pembulatan masuk ke bagian saya.
  void _splitEvenly() {
    final total = parseAmount(_total.text);
    if (total <= 0) {
      showSnack(context, 'Isi total tagihan dulu.');
      return;
    }
    final each = total ~/ (_people.length + 1);
    setState(() {
      for (final p in _people) {
        p.amount.text = each.toString();
      }
      _personal.text = (total - each * _people.length).toString();
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_diff != 0) {
      showSnack(context, 'Bagian pribadi + piutang harus sama dengan total (selisih ${rupiah(_diff)}).');
      return;
    }
    final shares = <MapEntry<String, int>>[];
    for (final p in _people) {
      shares.add(MapEntry(p.name.text.trim(), parseAmount(p.amount.text)));
    }
    await context.read<AppState>().addSplit(
          date: isoDate(_date),
          accountId: _accountId!,
          category: _category,
          note: _note.text.trim(),
          personalAmount: parseAmount(_personal.text),
          shares: shares,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Split Bill / Talangan')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AccountDropdown(
              accounts: accounts,
              value: _accountId,
              label: 'Dibayar dari',
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _total,
              label: 'Total tagihan',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Keterangan (mis. Makan bareng)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: 'Kategori bagian pribadi', border: OutlineInputBorder()),
              items: [for (final c in expenseCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            AmountField(
              controller: _personal,
              label: 'Bagian saya (Expense)',
              required: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Ditalangi untuk (Piutang)', style: tt.titleMedium)),
                TextButton(onPressed: _splitEvenly, child: const Text('Bagi rata')),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _people.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _people[i].name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nama', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi nama' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: AmountField(
                        controller: _people[i].amount,
                        label: 'Jumlah',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      onPressed: _people.length == 1
                          ? null
                          : () => setState(() {
                                _people.removeAt(i).dispose();
                              }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _people.add(_Person())),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Tambah orang'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: _diff == 0 ? cs.primaryContainer : cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _diff == 0
                      ? 'Pas. Piutang ${rupiah(_sharesSum)} + bagian saya ${rupiah(parseAmount(_personal.text))}.'
                      : 'Selisih ${rupiah(_diff)} dari total tagihan.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
