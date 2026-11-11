import 'package:flutter/foundation.dart';

import '../db/db_helper.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class AppState extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  bool loading = true;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  List<Account> accounts = [];
  List<TxModel> expenses = [];
  List<TxModel> incomes = [];
  List<TransferModel> transfers = [];
  List<Receivable> receivables = [];
  MonthSummary summary = const MonthSummary();

  int get totalBalance => accounts.fold(0, (s, a) => s + a.balance);

  int get outstanding =>
      receivables.where((r) => !r.settled).fold(0, (s, r) => s + r.amount);

  String accountName(int? id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return '-';
  }

  Future<void> load() async {
    accounts = await _db.accounts();
    expenses = await _db.transactionsByMonth(month, type: typeExpense);
    incomes = await _db.transactionsByMonth(month, type: typeIncome);
    transfers = await _db.transfersByMonth(month);
    receivables = await _db.receivables();
    summary = await _db.monthSummary(month);
    loading = false;
    notifyListeners();
  }

  Future<void> shiftMonth(int delta) async {
    month = DateTime(month.year, month.month + delta);
    await load();
  }

  // Akun
  Future<void> addAccount(String name, int initial) async {
    await _db.insertAccount(name, initial);
    await load();
  }

  Future<void> editAccount(Account a) async {
    await _db.updateAccount(a);
    await load();
  }

  Future<bool> removeAccount(int id) async {
    final ok = await _db.deleteAccount(id);
    if (ok) await load();
    return ok;
  }

  // Transaksi
  Future<void> addTransaction(TxModel t) async {
    await _db.insertTransaction(t);
    await load();
  }

  Future<void> removeTransaction(int id) async {
    await _db.deleteTransaction(id);
    await load();
  }

  // Transfer
  Future<void> addTransfer(TransferModel t) async {
    await _db.insertTransfer(t);
    await load();
  }

  Future<void> removeTransfer(int id) async {
    await _db.deleteTransfer(id);
    await load();
  }

  // Split bill & piutang
  Future<void> addSplit({
    required String date,
    required int accountId,
    required String category,
    required String note,
    required int personalAmount,
    required List<MapEntry<String, int>> shares,
  }) async {
    await _db.createSplit(
      date: date,
      accountId: accountId,
      category: category,
      note: note,
      personalAmount: personalAmount,
      shares: shares,
    );
    await load();
  }

  Future<void> settle(int id, int accountId, String date) async {
    await _db.settleReceivable(id, accountId, date);
    await load();
  }

  Future<void> unsettle(int id) async {
    await _db.unsettleReceivable(id);
    await load();
  }

  Future<void> removeReceivable(int id) async {
    await _db.deleteReceivable(id);
    await load();
  }
}
