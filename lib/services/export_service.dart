import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../db/db_helper.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

class ExportService {
  static final DbHelper _db = DbHelper.instance;

  // ------------------------------------------------------------- Excel

  /// Seluruh data -> .xlsx dengan sheet: Expense, Income, Transfer,
  /// Piutang, Resume Saldo. Return path jika tersimpan, null jika batal.
  static Future<String?> exportExcel() async {
    final accounts = await _db.accounts();
    final names = {for (final a in accounts) a.id!: a.name};
    String nm(int? id) => names[id] ?? '-';

    final txs = await _db.allTransactions();
    final transfers = await _db.transfersByMonth(null);
    final receivables = await _db.receivables();

    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet();
    if (defaultName != null) excel.rename(defaultName, 'Expense');

    void addHeader(Sheet s, List<String> h) =>
        s.appendRow(h.map<CellValue?>((e) => TextCellValue(e)).toList());

    // Expense
    final sExp = excel['Expense'];
    addHeader(sExp, ['Tanggal', 'Kategori', 'Sumber Dana', 'Keterangan', 'Jumlah']);
    for (final t in txs.where((t) => t.type == typeExpense)) {
      sExp.appendRow([
        TextCellValue(t.date),
        TextCellValue(t.category),
        TextCellValue(nm(t.accountId)),
        TextCellValue(t.note),
        IntCellValue(t.amount),
      ]);
    }

    // Income
    final sInc = excel['Income'];
    addHeader(sInc, ['Tanggal', 'Kategori', 'Sumber Dana', 'Keterangan', 'Jumlah']);
    for (final t in txs.where((t) => t.type == typeIncome)) {
      sInc.appendRow([
        TextCellValue(t.date),
        TextCellValue(t.category),
        TextCellValue(nm(t.accountId)),
        TextCellValue(t.note),
        IntCellValue(t.amount),
      ]);
    }

    // Transfer
    final sTr = excel['Transfer'];
    addHeader(sTr, ['Tanggal', 'Dari Akun', 'Ke Akun', 'Jumlah', 'Biaya Admin', 'Keterangan']);
    for (final t in transfers) {
      sTr.appendRow([
        TextCellValue(t.date),
        TextCellValue(nm(t.fromAccountId)),
        TextCellValue(nm(t.toAccountId)),
        IntCellValue(t.amount),
        IntCellValue(t.adminFee),
        TextCellValue(t.note),
      ]);
    }

    // Piutang
    final sRec = excel['Piutang'];
    addHeader(sRec, [
      'Tanggal', 'Nama', 'Ditalangi Dari', 'Keterangan', 'Jumlah',
      'Status', 'Tanggal Lunas', 'Dibayar Ke Akun',
    ]);
    for (final r in receivables) {
      sRec.appendRow([
        TextCellValue(r.date),
        TextCellValue(r.person),
        TextCellValue(nm(r.sourceAccountId)),
        TextCellValue(r.note),
        IntCellValue(r.amount),
        TextCellValue(r.settled ? 'Lunas' : 'Belum Lunas'),
        TextCellValue(r.settledDate ?? ''),
        TextCellValue(r.settled ? nm(r.settledAccountId) : ''),
      ]);
    }

    // Resume Saldo
    final sSum = excel['Resume Saldo'];
    addHeader(sSum, [
      'Akun', 'Saldo Awal', 'Pemasukan', 'Pengeluaran', 'Transfer Masuk',
      'Transfer Keluar', 'Talangan Piutang', 'Piutang Lunas Masuk', 'Saldo Terkini',
    ]);
    var total = 0;
    for (final a in accounts) {
      total += a.balance;
      sSum.appendRow([
        TextCellValue(a.name),
        IntCellValue(a.initialBalance),
        IntCellValue(a.income),
        IntCellValue(a.expense),
        IntCellValue(a.transferIn),
        IntCellValue(a.transferOut),
        IntCellValue(a.receivableOut),
        IntCellValue(a.receivableIn),
        IntCellValue(a.balance),
      ]);
    }
    sSum.appendRow([
      TextCellValue('TOTAL'),
      ...List<CellValue?>.filled(7, null),
      IntCellValue(total),
    ]);

    final data = excel.encode();
    if (data == null) throw StateError('Gagal membuat file Excel.');
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    return FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Excel',
      fileName: 'dompetku_$stamp.xlsx',
      bytes: Uint8List.fromList(data),
    );
  }

  // --------------------------------------------------------------- PDF

  /// Ringkasan bulanan. Transfer antar akun TIDAK dihitung sebagai
  /// pemasukan/pengeluaran (hanya biaya admin yang masuk pengeluaran).
  static Future<String?> exportMonthlyPdf(DateTime month) async {
    final accounts = await _db.accounts();
    final names = {for (final a in accounts) a.id!: a.name};
    String nm(int? id) => names[id] ?? '-';

    final summary = await _db.monthSummary(month);
    final txs = (await _db.transactionsByMonth(month)).reversed.toList();
    final transfers = (await _db.transfersByMonth(month)).reversed.toList();
    final receivables = await _db.receivables();
    final open = receivables.where((r) => !r.settled).toList();

    final perPerson = <String, int>{};
    for (final r in open) {
      perPerson[r.person] = (perPerson[r.person] ?? 0) + r.amount;
    }

    final doc = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

    pw.Widget h(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget table(List<String> headers, List<List<String>> rows,
        {Map<int, pw.Alignment>? align}) {
      if (rows.isEmpty) return pw.Text('Tidak ada data.');
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: align,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('Laporan Keuangan Bulanan',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text(monthLabel(month)),
          h('Ringkasan'),
          table(['Keterangan', 'Jumlah'], [
            ['Total Pemasukan', rupiah(summary.income)],
            ['Total Pengeluaran', rupiah(summary.expense)],
            ['Selisih', rupiah(summary.net)],
          ], align: {1: pw.Alignment.centerRight}),
          pw.SizedBox(height: 4),
          pw.Text('Transfer antar akun tidak dihitung sebagai pemasukan/pengeluaran.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          h('Pengeluaran per Kategori'),
          table(
            ['Kategori', 'Jumlah', '%'],
            summary.expenseByCategory.entries
                .map((e) => [
                      e.key,
                      rupiah(e.value),
                      summary.expense == 0
                          ? '0%'
                          : '${(e.value * 100 / summary.expense).toStringAsFixed(1)}%',
                    ])
                .toList(),
            align: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
          ),
          h('Daftar Transaksi'),
          table(
            ['Tanggal', 'Jenis', 'Kategori', 'Akun', 'Keterangan', 'Jumlah'],
            txs
                .map((t) => [
                      t.date,
                      t.type == typeIncome ? 'Masuk' : 'Keluar',
                      t.category,
                      nm(t.accountId),
                      t.note,
                      rupiah(t.amount),
                    ])
                .toList(),
            align: {5: pw.Alignment.centerRight},
          ),
          h('Transfer Antar Akun (informasi)'),
          table(
            ['Tanggal', 'Dari', 'Ke', 'Jumlah', 'Biaya Admin'],
            transfers
                .map((t) => [
                      t.date,
                      nm(t.fromAccountId),
                      nm(t.toAccountId),
                      rupiah(t.amount),
                      rupiah(t.adminFee),
                    ])
                .toList(),
            align: {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          ),
          h('Piutang Belum Lunas (per hari ini)'),
          table(
            ['Nama', 'Jumlah'],
            perPerson.entries.map((e) => [e.key, rupiah(e.value)]).toList(),
            align: {1: pw.Alignment.centerRight},
          ),
          h('Saldo Akun Terkini'),
          table(
            ['Akun', 'Saldo'],
            [
              ...accounts.map((a) => [a.name, rupiah(a.balance)]),
              ['TOTAL', rupiah(accounts.fold<int>(0, (s, a) => s + a.balance))],
            ],
            align: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 12),
          pw.Text('Dibuat ${dateLabel(DateTime.now())} oleh Dompetku (offline)',
              style: bold.copyWith(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );

    final bytes = await doc.save();
    return FilePicker.platform.saveFile(
      dialogTitle: 'Simpan PDF',
      fileName: 'laporan_${DateFormat('yyyy-MM').format(month)}.pdf',
      bytes: bytes,
    );
  }
}
