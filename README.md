# Dompetku - Personal Finance Manager (Flutter, 100% offline)

## Struktur

```
lib/
  main.dart                      # entry point, tema Material 3
  models/models.dart             # Account, TxModel, TransferModel, Receivable, MonthSummary
  db/db_helper.dart              # SQLite (sqflite): skema, saldo, transfer, split bill, backup/restore
  providers/app_state.dart       # state (provider)
  services/export_service.dart   # Excel (.xlsx, 5 sheet) + PDF ringkasan bulanan
  services/backup_service.dart   # backup/restore .json
  utils/                         # format rupiah/tanggal, konstanta kategori
  widgets/common.dart            # field jumlah, tanggal, dropdown akun, dll
  screens/                       # dashboard, transaksi, piutang, akun, input, transfer, split bill, export
android/app/src/main/AndroidManifest.xml   # TANPA android.permission.INTERNET
```

## Cara build APK

```bash
flutter create --platforms=android --org com.pribadi --project-name dompetku .
# lalu timpa file hasil generate dengan isi folder ini:
#   lib/, pubspec.yaml, android/app/src/main/AndroidManifest.xml
flutter pub get
flutter build apk --release --split-per-abi
```

APK ada di `build/app/outputs/flutter-apk/`.

## Pastikan tanpa izin internet

Build **debug/profile** bawaan Flutter menambahkan INTERNET (untuk hot reload) lewat
`android/app/src/debug/AndroidManifest.xml` dan `profile/`. Build **release** tidak.
Hapus baris itu di kedua file tersebut jika ingin aman juga di debug, lalu verifikasi:

```bash
aapt dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Hasilnya tidak boleh memuat `android.permission.INTERNET`.

## Aturan saldo

```
Saldo = Saldo Awal + Pemasukan - Pengeluaran
        + Transfer Masuk - Transfer Keluar
        - Talangan Piutang (uang keluar saat menalangi)
        + Piutang Lunas (uang kembali masuk)
```

- Transfer tidak ikut laporan bulanan; hanya biaya admin yang dicatat sebagai Expense "Biaya Admin".
- Split bill Rp150.000 dari Mandiri: Expense pribadi Rp50.000 + 2 piutang @Rp50.000
  (tidak masuk Expense). Mandiri berkurang Rp150.000.
- Tandai Lunas ke ShopeePay: saldo ShopeePay +Rp50.000, status Lunas, tidak ada Income baru.

## Catatan

- Export/backup memakai dialog simpan sistem (Storage Access Framework) sehingga tidak butuh izin storage.
- Jumlah disimpan sebagai integer Rupiah (tanpa pecahan) agar tidak ada selisih pembulatan.
- Kode ini belum dikompilasi di lingkungan pembuatnya (tidak ada Flutter SDK); jalankan `flutter analyze` dulu.
