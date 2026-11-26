import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _databaseFuture;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _databaseFuture ??= _initDB('savmon.db');
      _database = await _databaseFuture!;
      return _database!;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        balance REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE transactions ADD COLUMN note TEXT NOT NULL DEFAULT ''",
      );
    }

    if (oldVersion < 3) {
      await db.insert('allocations', {
        'category_name': 'Hiburan',
        'balance': 0.0,
      });
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE app_settings (
          setting_key TEXT PRIMARY KEY,
          setting_value TEXT NOT NULL
        )
      ''');
      await db.insert('app_settings', {
        'setting_key': 'allocation_month',
        'setting_value': _monthKey(DateTime.now()),
      });
    }

    if (oldVersion < 5) {
      await db.insert('app_settings', {
        'setting_key': 'user_name',
        'setting_value': 'Pengguna',
      });
    }
  }

  static String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  Future<bool> resetAllocationsForNewMonth() async {
    final db = await instance.database;
    final currentMonth = _monthKey(DateTime.now());

    return db.transaction<bool>((txn) async {
      final result = await txn.query(
        'app_settings',
        columns: ['setting_value'],
        where: 'setting_key = ?',
        whereArgs: ['allocation_month'],
        limit: 1,
      );

      if (result.isEmpty) {
        await txn.insert('app_settings', {
          'setting_key': 'allocation_month',
          'setting_value': currentMonth,
        });
        return false;
      }

      final savedMonth = result.first['setting_value'] as String;
      if (savedMonth == currentMonth) return false;

      await txn.update('allocations', {'balance': 0.0});
      await txn.update(
        'app_settings',
        {'setting_value': currentMonth},
        where: 'setting_key = ?',
        whereArgs: ['allocation_month'],
      );
      return true;
    });
  }

  Future<void> saveAllocations(double totalBalance) async {
    final db = await instance.database;
    final currentMonth = _monthKey(DateTime.now());

    await db.transaction((txn) async {
      await txn.delete('allocations');
      await _insertAllocation(txn, 'Kebutuhan', totalBalance * 0.36);
      await _insertAllocation(txn, 'Darurat', totalBalance * 0.18);
      await _insertAllocation(txn, 'Investasi', totalBalance * 0.18);
      await _insertAllocation(txn, 'Tabungan', totalBalance * 0.18);
      await _insertAllocation(txn, 'Hiburan', totalBalance * 0.10);
      await txn.insert('app_settings', {
        'setting_key': 'allocation_month',
        'setting_value': currentMonth,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _insertAllocation(
    Transaction txn,
    String category,
    double amount,
  ) async {
    await txn.insert('allocations', {
      'category_name': category,
      'balance': amount,
    });
  }

  Future<Map<String, double>> getAllocations() async {
    final db = await instance.database;
    final result = await db.query('allocations');

    final allocations = <String, double>{
      'Kebutuhan': 0.0,
      'Darurat': 0.0,
      'Investasi': 0.0,
      'Tabungan': 0.0,
      'Hiburan': 0.0,
    };

    for (final row in result) {
      allocations[row['category_name'] as String] = (row['balance'] as num)
          .toDouble();
    }
    return allocations;
  }

  Future<void> addIncome(double amount, {String note = ''}) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Harus lebih besar dari 0.');
    }

    await resetAllocationsForNewMonth();
    final db = await instance.database;
    await db.transaction((txn) async {
      const shares = <String, double>{
        'Kebutuhan': 0.36,
        'Darurat': 0.18,
        'Investasi': 0.18,
        'Tabungan': 0.18,
        'Hiburan': 0.10,
      };

      for (final entry in shares.entries) {
        final result = await txn.query(
          'allocations',
          columns: ['balance'],
          where: 'category_name = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        final addedAmount = amount * entry.value;
        if (result.isEmpty) {
          await txn.insert('allocations', {
            'category_name': entry.key,
            'balance': addedAmount,
          });
        } else {
          final balance = (result.first['balance'] as num).toDouble();
          await txn.update(
            'allocations',
            {'balance': balance + addedAmount},
            where: 'category_name = ?',
            whereArgs: [entry.key],
          );
        }
      }

      await txn.insert('transactions', {
        'title': 'Pemasukan',
        'amount': amount,
        'category': 'Pemasukan',
        'type': 'income',
        'date': DateTime.now().toIso8601String(),
        'note': note.trim(),
      });
    });
  }

  Future<void> addExpense(
    String category,
    double amount, {
    String note = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Harus lebih besar dari 0.');
    }

    await resetAllocationsForNewMonth();
    final db = await instance.database;
    await db.transaction((txn) async {
      final result = await txn.query(
        'allocations',
        where: 'category_name = ?',
        whereArgs: [category],
        limit: 1,
      );

      if (result.isEmpty) {
        throw ArgumentError.value(
          category,
          'category',
          'Kategori tidak ditemukan.',
        );
      }

      final currentBalance = (result.first['balance'] as num).toDouble();
      if (amount > currentBalance) {
        throw StateError('Saldo kategori $category tidak mencukupi.');
      }

      await txn.update(
        'allocations',
        {'balance': currentBalance - amount},
        where: 'category_name = ?',
        whereArgs: [category],
      );

      await txn.insert('transactions', {
        'title': 'Pengeluaran $category',
        'amount': amount,
        'category': category,
        'type': 'expense',
        'date': DateTime.now().toIso8601String(),
        'note': note.trim(),
      });
    });
  }

  Future<Map<String, double>> getMonthlySummary(DateTime month) async {
    final transactions = await getTransactionsForMonth(month);
    final summary = <String, double>{'income': 0, 'expense': 0};

    for (final transaction in transactions) {
      final type = transaction['type']?.toString() ?? '';
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'income' || type == 'expense') {
        summary[type] = (summary[type] ?? 0) + amount;
      }
    }
    return summary;
  }

  Future<List<Map<String, Object?>>> getTransactionsForMonth(
    DateTime month,
  ) async {
    final db = await instance.database;
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    return db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, Object?>>> getRecentTransactions({
    int limit = 5,
  }) async {
    final db = await instance.database;
    return db.query(
      'transactions',
      where: 'type IN (?, ?)',
      whereArgs: ['income', 'expense'],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<String> getUserName() async {
    final db = await instance.database;
    final result = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: ['user_name'],
      limit: 1,
    );
    if (result.isEmpty) return 'Pengguna';
    return result.first['setting_value'] as String;
  }

  Future<void> saveUserName(String name) async {
    final db = await instance.database;
    await db.insert('app_settings', {
      'setting_key': 'user_name',
      'setting_value': name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
