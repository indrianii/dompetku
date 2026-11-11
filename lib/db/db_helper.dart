import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

/// Satu-satunya pintu ke SQLite lokal. Tidak ada jaringan sama sekali.
class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'dompetku.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database d, int version) async {
    await d.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        initial_balance INTEGER NOT NULL DEFAULT 0
      )''');
    await d.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        note TEXT,
        amount INTEGER NOT NULL,
        transfer_id INTEGER
      )''');
    await d.execute('''
      CREATE TABLE transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        from_account_id INTEGER NOT NULL,
        to_account_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        admin_fee INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )''');
    await d.execute('''
      CREATE TABLE receivables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        source_account_id INTEGER NOT NULL,
        settled INTEGER NOT NULL DEFAULT 0,
        settled_date TEXT,
        settled_account_id INTEGER
      )''');
    await d.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await d.execute('CREATE INDEX idx_tr_date ON transfers(date)');

    final b = d.batch();
    for (final n in defaultAccounts) {
      b.insert('accounts', {'name': n, 'initial_balance': 0});
    }
    await b.commit(noResult: true);
  }

  // ---------------------------------------------------------------- Akun

  static const _balanceSql = '''
    SELECT a.id, a.name, a.initial_balance,
      COALESCE((SELECT SUM(amount) FROM transactions
                WHERE account_id = a.id AND type = 'income'), 0) AS income,
      COALESCE((SELECT SUM(amount) FROM transactions
                WHERE account_id = a.id AND type = 'expense'), 0) AS expense,
      COALESCE((SELECT SUM(amount) FROM transfers
                WHERE to_account_id = a.id), 0) AS tr_in,
      COALESCE((SELECT SUM(amount) FROM transfers
                WHERE from_account_id = a.id), 0) AS tr_out,
      COALESCE((SELECT SUM(amount) FROM receivables
                WHERE source_account_id = a.id), 0) AS rec_out,
      COALESCE((SELECT SUM(amount) FROM receivables
                WHERE settled = 1 AND settled_account_id = a.id), 0) AS rec_in
    FROM accounts a ORDER BY a.id''';

  Future<List<Account>> accounts() async {
    final d = await db;
    final rows = await d.rawQuery(_balanceSql);
    return rows.map(Account.fromMap).toList();
  }

  Future<void> insertAccount(String name, int initialBalance) async {
    final d = await db;
    await d.insert('accounts', {'name': name, 'initial_balance': initialBalance});
  }

  Future<void> updateAccount(Account a) async {
    final d = await db;
    await d.update('accounts', {'name': a.name, 'initial_balance': a.initialBalance},
        where: 'id = ?', whereArgs: [a.id]);
  }

  /// Mengembalikan false jika akun masih dipakai oleh data lain.
  Future<bool> deleteAccount(int id) async {
    final d = await db;
    final used = Sqflite.firstIntValue(await d.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM transactions WHERE account_id = ?) +
        (SELECT COUNT(*) FROM transfers WHERE from_account_id = ? OR to_account_id = ?) +
        (SELECT COUNT(*) FROM receivables WHERE source_account_id = ? OR settled_account_id = ?)
    ''', [id, id, id, id, id])) ?? 0;
    if (used > 0) return false;
    await d.delete('accounts', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // ---------------------------------------------------------- Transaksi

  (String, String) _monthRange(DateTime m) =>
      (isoDate(DateTime(m.year, m.month)), isoDate(DateTime(m.year, m.month + 1)));

  Future<List<TxModel>> transactionsByMonth(DateTime month, {String? type}) async {
    final d = await db;
    final (start, end) = _monthRange(month);
    final rows = await d.query(
      'transactions',
      where: type == null ? 'date >= ? AND date < ?' : 'date >= ? AND date < ? AND type = ?',
      whereArgs: type == null ? [start, end] : [start, end, type],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TxModel.fromMap).toList();
  }

  Future<List<TxModel>> allTransactions() async {
    final d = await db;
    final rows = await d.query('transactions', orderBy: 'date ASC, id ASC');
    return rows.map(TxModel.fromMap).toList();
  }

  Future<void> insertTransaction(TxModel t) async {
    final d = await db;
    await d.insert('transactions', t.toMap()..remove('id'));
  }

  Future<void> deleteTransaction(int id) async {
    final d = await db;
    await d.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<MonthSummary> monthSummary(DateTime month) async {
    final d = await db;
    final (start, end) = _monthRange(month);
    final totals = await d.rawQuery(
        'SELECT type, SUM(amount) AS s FROM transactions '
        'WHERE date >= ? AND date < ? GROUP BY type',
        [start, end]);
    var income = 0, expense = 0;
    for (final r in totals) {
      final s = (r['s'] as num?)?.toInt() ?? 0;
      if (r['type'] == typeIncome) income = s;
      if (r['type'] == typeExpense) expense = s;
    }
    final cats = await d.rawQuery(
        'SELECT category, SUM(amount) AS s FROM transactions '
        "WHERE type = 'expense' AND date >= ? AND date < ? "
        'GROUP BY category ORDER BY s DESC',
        [start, end]);
    return MonthSummary(
      income: income,
      expense: expense,
      expenseByCategory: {
        for (final r in cats) r['category'] as String: (r['s'] as num).toInt()
      },
    );
  }

  // ----------------------------------------------------------- Transfer

  Future<List<TransferModel>> transfersByMonth(DateTime? month) async {
    final d = await db;
    List<Map<String, Object?>> rows;
    if (month == null) {
      rows = await d.query('transfers', orderBy: 'date ASC, id ASC');
    } else {
      final (start, end) = _monthRange(month);
      rows = await d.query('transfers',
          where: 'date >= ? AND date < ?',
          whereArgs: [start, end],
          orderBy: 'date DESC, id DESC');
    }
    return rows.map(TransferModel.fromMap).toList();
  }

  /// Transfer tidak masuk Pemasukan/Pengeluaran. Hanya biaya admin yang
  /// dicatat sebagai Expense kategori "Biaya Admin" (dari akun asal).
  Future<void> insertTransfer(TransferModel t) async {
    final d = await db;
    await d.transaction((txn) async {
      final id = await txn.insert('transfers', t.toMap()..remove('id'));
      if (t.adminFee > 0) {
        await txn.insert(
          'transactions',
          TxModel(
            type: typeExpense,
            date: t.date,
            category: adminFeeCategory,
            accountId: t.fromAccountId,
            note: t.note.isEmpty ? 'Biaya admin transfer' : 'Biaya admin: ${t.note}',
            amount: t.adminFee,
            transferId: id,
          ).toMap()
            ..remove('id'),
        );
      }
    });
  }

  Future<void> deleteTransfer(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('transactions', where: 'transfer_id = ?', whereArgs: [id]);
      await txn.delete('transfers', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ------------------------------------------------- Split bill / Piutang

  /// Bayar [personalAmount] + sum(shares) dari [accountId].
  /// Bagian pribadi -> Expense. Bagian teman -> Piutang (bukan Expense).
  Future<void> createSplit({
    required String date,
    required int accountId,
    required String category,
    required String note,
    required int personalAmount,
    required List<MapEntry<String, int>> shares,
  }) async {
    final d = await db;
    await d.transaction((txn) async {
      if (personalAmount > 0) {
        await txn.insert(
          'transactions',
          TxModel(
            type: typeExpense,
            date: date,
            category: category,
            accountId: accountId,
            note: note,
            amount: personalAmount,
          ).toMap()
            ..remove('id'),
        );
      }
      for (final s in shares) {
        await txn.insert(
          'receivables',
          Receivable(
            person: s.key,
            amount: s.value,
            date: date,
            note: note,
            sourceAccountId: accountId,
          ).toMap()
            ..remove('id'),
        );
      }
    });
  }

  Future<List<Receivable>> receivables() async {
    final d = await db;
    final rows = await d.query('receivables', orderBy: 'settled ASC, date DESC, id DESC');
    return rows.map(Receivable.fromMap).toList();
  }

  /// Saldo akun tujuan bertambah, TANPA membuat Income baru.
  Future<void> settleReceivable(int id, int accountId, String date) async {
    final d = await db;
    await d.update(
      'receivables',
      {'settled': 1, 'settled_date': date, 'settled_account_id': accountId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> unsettleReceivable(int id) async {
    final d = await db;
    await d.update(
      'receivables',
      {'settled': 0, 'settled_date': null, 'settled_account_id': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteReceivable(int id) async {
    final d = await db;
    await d.delete('receivables', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------ Backup/Restore

  static const _tables = ['accounts', 'transactions', 'transfers', 'receivables'];

  Future<Map<String, dynamic>> dumpAll() async {
    final d = await db;
    return {
      'app': 'dompetku',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      for (final t in _tables) t: await d.query(t, orderBy: 'id ASC'),
    };
  }

  /// Mengganti SELURUH isi database dengan isi backup (atomik).
  Future<void> restoreAll(Map<String, dynamic> data) async {
    if (data['app'] != 'dompetku') {
      throw const FormatException('Bukan file backup Dompetku.');
    }
    for (final t in _tables) {
      if (data[t] is! List) throw FormatException('Data "$t" tidak ditemukan.');
    }
    final d = await db;
    await d.transaction((txn) async {
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      for (final t in _tables) {
        for (final row in data[t] as List) {
          await txn.insert(t, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }
}
