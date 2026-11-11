import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() job, String okMsg) async {
    setState(() => _busy = true);
    try {
      final path = await job();
      if (mounted) showSnack(context, path == null ? 'Dibatalkan.' : okMsg);
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await confirm(
      context,
      'Restore data?',
      'Seluruh data saat ini akan DIGANTI dengan isi file backup. '
      'Pastikan sudah membuat backup terbaru.',
      ok: 'Pilih File',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final done = await BackupService.restore();
      if (done && mounted) {
        await context.read<AppState>().load();
        if (mounted) showSnack(context, 'Data berhasil dipulihkan.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Restore gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = context.watch<AppState>().month;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Export & Backup')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(context, 'Export'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.table_chart_outlined),
                      title: const Text('Export Excel (.xlsx)'),
                      subtitle: const Text('Expense, Income, Transfer, Piutang, Resume Saldo'),
                      onTap: _busy ? null : () => _run(ExportService.exportExcel, 'Excel tersimpan.'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Ringkasan bulanan PDF'),
                      subtitle: Text('Periode: ${monthLabel(month)} (ubah di tab Ringkasan/Transaksi)'),
                      onTap: _busy
                          ? null
                          : () => _run(() => ExportService.exportMonthlyPdf(month), 'PDF tersimpan.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(context, 'Backup'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Backup ke .json'),
                      subtitle: const Text('Simpan seluruh database ke file lokal'),
                      onTap: _busy ? null : () => _run(BackupService.backup, 'Backup tersimpan.'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.settings_backup_restore, color: cs.error),
                      title: const Text('Restore dari .json'),
                      subtitle: const Text('Mengganti seluruh data dengan isi file backup'),
                      onTap: _busy ? null : _restore,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aplikasi ini 100% offline dan tidak memiliki izin internet. '
                'Data hanya tersimpan di perangkat. Lakukan backup berkala dan '
                'simpan file di tempat yang aman.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );
}
