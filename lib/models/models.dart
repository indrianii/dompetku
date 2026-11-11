int _int(Object? v) => v == null ? 0 : (v as num).toInt();

/// Akun / sumber dana beserta komponen perhitungan saldonya.
class Account {
  final int? id;
  final String name;
  final int initialBalance;
  final int income;
  final int expense;
  final int transferIn;
  final int transferOut;
  final int receivableOut; // talangan yang keluar dari akun ini
  final int receivableIn; // piutang lunas yang masuk ke akun ini

  const Account({
    this.id,
    required this.name,
    required this.initialBalance,
    this.income = 0,
    this.expense = 0,
    this.transferIn = 0,
    this.transferOut = 0,
    this.receivableOut = 0,
    this.receivableIn = 0,
  });

  /// Saldo Awal + Pemasukan - Pengeluaran +/- Transfer - Talangan + Piutang Lunas
  int get balance =>
      initialBalance +
      income -
      expense +
      transferIn -
      transferOut -
      receivableOut +
      receivableIn;

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'initial_balance': initialBalance};

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        initialBalance: _int(m['initial_balance']),
        income: _int(m['income']),
        expense: _int(m['expense']),
        transferIn: _int(m['tr_in']),
        transferOut: _int(m['tr_out']),
        receivableOut: _int(m['rec_out']),
        receivableIn: _int(m['rec_in']),
      );
}

class TxModel {
  final int? id;
  final String type; // income | expense
  final String date; // yyyy-MM-dd
  final String category;
  final int accountId;
  final String note;
  final int amount;
  final int? transferId; // terisi jika ini biaya admin sebuah transfer

  const TxModel({
    this.id,
    required this.type,
    required this.date,
    required this.category,
    required this.accountId,
    this.note = '',
    required this.amount,
    this.transferId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'date': date,
        'category': category,
        'account_id': accountId,
        'note': note,
        'amount': amount,
        'transfer_id': transferId,
      };

  factory TxModel.fromMap(Map<String, Object?> m) => TxModel(
        id: m['id'] as int?,
        type: m['type'] as String,
        date: m['date'] as String,
        category: m['category'] as String,
        accountId: _int(m['account_id']),
        note: (m['note'] as String?) ?? '',
        amount: _int(m['amount']),
        transferId: m['transfer_id'] as int?,
      );
}

class TransferModel {
  final int? id;
  final String date;
  final int fromAccountId;
  final int toAccountId;
  final int amount;
  final int adminFee;
  final String note;

  const TransferModel({
    this.id,
    required this.date,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.adminFee = 0,
    this.note = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        'admin_fee': adminFee,
        'note': note,
      };

  factory TransferModel.fromMap(Map<String, Object?> m) => TransferModel(
        id: m['id'] as int?,
        date: m['date'] as String,
        fromAccountId: _int(m['from_account_id']),
        toAccountId: _int(m['to_account_id']),
        amount: _int(m['amount']),
        adminFee: _int(m['admin_fee']),
        note: (m['note'] as String?) ?? '',
      );
}

class Receivable {
  final int? id;
  final String person;
  final int amount;
  final String date;
  final String note;
  final int sourceAccountId; // akun yang menalangi
  final bool settled;
  final String? settledDate;
  final int? settledAccountId; // akun tempat uang kembali masuk

  const Receivable({
    this.id,
    required this.person,
    required this.amount,
    required this.date,
    this.note = '',
    required this.sourceAccountId,
    this.settled = false,
    this.settledDate,
    this.settledAccountId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'person': person,
        'amount': amount,
        'date': date,
        'note': note,
        'source_account_id': sourceAccountId,
        'settled': settled ? 1 : 0,
        'settled_date': settledDate,
        'settled_account_id': settledAccountId,
      };

  factory Receivable.fromMap(Map<String, Object?> m) => Receivable(
        id: m['id'] as int?,
        person: m['person'] as String,
        amount: _int(m['amount']),
        date: m['date'] as String,
        note: (m['note'] as String?) ?? '',
        sourceAccountId: _int(m['source_account_id']),
        settled: _int(m['settled']) == 1,
        settledDate: m['settled_date'] as String?,
        settledAccountId: m['settled_account_id'] as int?,
      );
}

class MonthSummary {
  final int income;
  final int expense;
  final Map<String, int> expenseByCategory;

  const MonthSummary({
    this.income = 0,
    this.expense = 0,
    this.expenseByCategory = const {},
  });

  int get net => income - expense;
}
