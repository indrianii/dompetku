import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _fee = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  int? _from;
  int? _to;

  @override
  void initState() {
    super.initState();
    final accs = context.read<AppState>().accounts;
    if (accs.length >= 2) {
      _from = accs[0].id;
      _to = accs[1].id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_from == _to) {
      showSnack(context, 'Akun asal dan tujuan harus berbeda.');
      return;
    }
    await context.read<AppState>().addTransfer(TransferModel(
          date: isoDate(_date),
          fromAccountId: _from!,
          toAccountId: _to!,
          amount: parseAmount(_amount.text),
          adminFee: parseAmount(_fee.text),
          note: _note.text.trim(),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer / Top-Up')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AccountDropdown(
              accounts: accounts,
              value: _from,
              label: 'Dari akun',
              onChanged: (v) => setState(() => _from = v),
            ),
            const SizedBox(height: 16),
            AccountDropdown(
              accounts: accounts,
              value: _to,
              label: 'Ke akun',
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: 16),
            AmountField(controller: _amount),
            const SizedBox(height: 16),
            AmountField(controller: _fee, label: 'Biaya admin (opsional)', required: false),
            const SizedBox(height: 4),
            Text(
              'Biaya admin dicatat otomatis sebagai pengeluaran "Biaya Admin" dari akun asal. '
              'Transfernya sendiri tidak dihitung sebagai pemasukan/pengeluaran.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Keterangan', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Simpan Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
