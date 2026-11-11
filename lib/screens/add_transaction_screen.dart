import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class AddTransactionScreen extends StatefulWidget {
  final String type; // income | expense
  const AddTransactionScreen({super.key, required this.type});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  late String _category;
  int? _accountId;

  bool get _isIncome => widget.type == typeIncome;
  List<String> get _cats => _isIncome ? incomeCategories : expenseCategories;

  @override
  void initState() {
    super.initState();
    _category = _cats.first;
    final accs = context.read<AppState>().accounts;
    if (accs.isNotEmpty) _accountId = accs.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AppState>().addTransaction(TxModel(
          type: widget.type,
          date: isoDate(_date),
          category: _category,
          accountId: _accountId!,
          note: _note.text.trim(),
          amount: parseAmount(_amount.text),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    return Scaffold(
      appBar: AppBar(title: Text(_isIncome ? 'Pemasukan Baru' : 'Pengeluaran Baru')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AmountField(controller: _amount),
            const SizedBox(height: 16),
            DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            AccountDropdown(
              accounts: accounts,
              value: _accountId,
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Keterangan', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
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
