import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _dialog(BuildContext context, {Account? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final initial = TextEditingController(text: (existing?.initialBalance ?? 0).toString());
    final form = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(existing == null ? 'Akun Baru' : 'Edit Akun'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama akun', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi nama' : null,
              ),
              const SizedBox(height: 12),
              AmountField(controller: initial, label: 'Saldo awal', required: false),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final st = context.read<AppState>();
      try {
        if (existing == null) {
          await st.addAccount(name.text.trim(), parseAmount(initial.text));
        } else {
          await st.editAccount(Account(
            id: existing.id,
            name: name.text.trim(),
            initialBalance: parseAmount(initial.text),
          ));
        }
      } catch (_) {
        if (context.mounted) showSnack(context, 'Nama akun sudah dipakai.');
      }
    }
    name.dispose();
    initial.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        OutlinedButton.icon(
          onPressed: () => _dialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Akun'),
        ),
        const SizedBox(height: 12),
        for (final a in s.accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                onTap: () => _dialog(context, existing: a),
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.account_balance_wallet_outlined, color: cs.onPrimaryContainer, size: 20),
                ),
                title: Text(a.name),
                subtitle: Text('Saldo awal ${rupiah(a.initialBalance)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rupiah(a.balance),
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: a.balance < 0 ? cs.error : null)),
                    IconButton(
                      tooltip: 'Hapus akun',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirm(context, 'Hapus akun?', a.name, ok: 'Hapus')) return;
                        final removed = await s.removeAccount(a.id!);
                        if (!removed && context.mounted) {
                          showSnack(context, 'Akun masih punya transaksi/transfer/piutang, tidak bisa dihapus.');
                        }
                      },
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
