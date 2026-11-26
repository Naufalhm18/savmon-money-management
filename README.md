# SavMon - Aplikasi Manajemen Keuangan

SavMon adalah aplikasi pencatatan keuangan pribadi yang membantu pengguna mencatat pemasukan dan pengeluaran, mengelola alokasi dana, serta melihat ringkasan transaksi bulanan.

## Fitur

- Mencatat pemasukan dan pengeluaran beserta catatan.
- Membagi pemasukan ke dalam lima kategori: Kebutuhan (36%), Darurat (18%), Investasi (18%), Tabungan (18%), dan Hiburan (10%).
- Melihat saldo alokasi dan ringkasan transaksi bulanan.
- Menelusuri riwayat transaksi berdasarkan bulan.
- Mengubah nama profil dan menyembunyikan saldo.
- Menyimpan data secara lokal di perangkat menggunakan SQLite.

> SavMon belum menyediakan login atau sinkronisasi data online. Data tersimpan di perangkat yang digunakan.

## Teknologi

- Flutter dan Dart
- SQLite melalui paket `sqflite`

## Menjalankan proyek

Pastikan Flutter SDK sudah terpasang, lalu jalankan perintah berikut dari folder proyek:

```bash
flutter pub get
flutter run
```

## Struktur utama

- `lib/main.dart` - antarmuka dan alur aplikasi.
- `lib/database_helper.dart` - penyimpanan dan pengelolaan data lokal.

## Catatan

Persentase alokasi pemasukan saat ini ditetapkan di aplikasi. Pengeluaran dicatat pada kategori terkait dan tidak dapat melebihi saldo kategori tersebut.
