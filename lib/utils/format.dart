import 'package:intl/intl.dart';

final NumberFormat _rp =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String rupiah(num v) => _rp.format(v);

String dateLabel(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

String monthLabel(DateTime d) => DateFormat('MMMM yyyy', 'id_ID').format(d);

/// Format penyimpanan di SQLite: yyyy-MM-dd (aman untuk perbandingan string).
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseIso(String s) => DateTime.parse(s);
