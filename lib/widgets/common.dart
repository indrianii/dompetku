import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';

int parseAmount(String s) => int.tryParse(s.trim()) ?? 0;

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;

  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Jumlah',
    this.required = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (!required && (v == null || v.isEmpty)) return null;
        return parseAmount(v ?? '') <= 0 ? 'Isi jumlah' : null;
      },
    );
  }
}

class DateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Tanggal',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (p != null) onChanged(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(dateLabel(value)),
      ),
    );
  }
}

class AccountDropdown extends StatelessWidget {
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;

  const AccountDropdown({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.label = 'Sumber Dana',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Pilih akun' : null,
    );
  }
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => s.shiftMonth(-1),
        ),
        SizedBox(
          width: 160,
          child: Text(
            monthLabel(s.month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => s.shiftMonth(1),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(BuildContext context, String title, String body,
    {String ok = 'Ya'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}
