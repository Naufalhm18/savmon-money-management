import 'package:flutter/material.dart';

import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SavMonApp());
}

class SavMonApp extends StatelessWidget {
  const SavMonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SavMon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  Map<String, double> _allocations = {
    'Kebutuhan': 0,
    'Darurat': 0,
    'Investasi': 0,
    'Tabungan': 0,
    'Hiburan': 0,
  };
  Map<String, double> _monthlySummary = {'income': 0, 'expense': 0};
  List<Map<String, Object?>> _recentTransactions = [];

  int _selectedIndex = 0;
  String _transactionType = 'expense';
  String _selectedCategory = 'Kebutuhan';
  String _userName = 'Pengguna';
  bool _hideBalance = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<Map<String, Object?>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transactionsFuture = DatabaseHelper.instance.getTransactionsForMonth(
      _selectedMonth,
    );
    _loadDashboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    _noteController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboard();
    }
  }


  Future<void> _loadDashboard() async {
    try {
      final monthWasReset = await DatabaseHelper.instance
          .resetAllocationsForNewMonth();
      final allocations = await DatabaseHelper.instance.getAllocations();
      final now = DateTime.now();
      final summary = await DatabaseHelper.instance.getMonthlySummary(now);
      final recent = await DatabaseHelper.instance.getRecentTransactions();
      final name = await DatabaseHelper.instance.getUserName();
      if (!mounted) return;

      setState(() {
        _allocations = allocations;
        _monthlySummary = summary;
        _recentTransactions = recent;
        _userName = name;
        if (_nameController.text.isEmpty) _nameController.text = name;
      });

      if (monthWasReset) {
        _showMessage(
          'Bulan baru: saldo alokasi direset. Catat pemasukan bulan ini.',
        );
      }
    } catch (error) {
      _showMessage('Gagal memuat data: $error');
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Masukkan nominal lebih besar dari 0.');
      return;
    }

    try {
      if (_transactionType == 'income') {
        await DatabaseHelper.instance.addIncome(
          amount,
          note: _noteController.text.trim(),
        );
      } else {
        await DatabaseHelper.instance.addExpense(
          _selectedCategory,
          amount,
          note: _noteController.text.trim(),
        );
      }

      await _loadDashboard();
      if (!mounted) return;
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      setState(() {
        _selectedMonth = currentMonth;
        _transactionsFuture = DatabaseHelper.instance.getTransactionsForMonth(
          currentMonth,
        );
      });
      _amountController.clear();
      _noteController.clear();
      FocusScope.of(context).unfocus();
      _showMessage(
        _transactionType == 'income'
            ? 'Pemasukan berhasil dicatat dan dialokasikan.'
            : 'Pengeluaran berhasil dicatat.',
      );
    } catch (error) {
      await _loadDashboard();
      _showMessage('Gagal menyimpan transaksi: $error');
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nama tidak boleh kosong.');
      return;
    }

    try {
      await DatabaseHelper.instance.saveUserName(name);
      if (!mounted) return;
      setState(() => _userName = name);
      _showMessage('Nama profil berhasil disimpan.');
    } catch (error) {
      _showMessage('Gagal menyimpan nama: $error');
    }
  }

  String _suggestCategoryFromNote(String note) {
    final text = note
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    bool containsAny(List<String> keywords) =>
        keywords.any((keyword) => text.contains(keyword));

    if (containsAny([
      'darurat',
      'kecelakaan',
      'rumah sakit',
      'igd',
      'dokter',
      'obat',
      'ban bocor',
    ])) {
      return 'Darurat';
    }
    if (containsAny([
      'investasi',
      'saham',
      'reksa dana',
      'reksadana',
      'obligasi',
      'emas',
      'crypto',
      'kripto',
      'modal usaha',
    ])) {
      return 'Investasi';
    }
    if (containsAny([
      'tabungan',
      'menabung',
      'nabung',
      'simpan uang',
      'tabung',
    ])) {
      return 'Tabungan';
    }
    if (containsAny([
      'hiburan',
      'touring',
      'jalan jalan',
      'liburan',
      'rekreasi',
      'wisata',
      'jajan',
      'nongkrong',
      'bioskop',
      'nonton',
      'game',
      'konser',
      'hobi',
      'kafe',
      'cafe',
      'snack',
      'cemilan',
      'camilan',
    ])) {
      return 'Hiburan';
    }
    return 'Kebutuhan';
  }

  void _openTransactionForm(String type) {
    setState(() {
      _selectedIndex = 1;
      _transactionType = type;
      if (type == 'expense') {
        _selectedCategory = _suggestCategoryFromNote(_noteController.text);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Beranda', 'Transaksi', 'Profil'];
    final pages = [_buildHomePage(), _buildAccountPage(), _buildProfilePage()];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    final totalBalance = _allocations.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final income = _monthlySummary['income'] ?? 0;
    final expense = _monthlySummary['expense'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selamat datang,'),
                    Text(
                      '$_userName!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Buka profil',
                onPressed: () => setState(() => _selectedIndex = 2),
                icon: const CircleAvatar(child: Icon(Icons.person_outline)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Saldo tersedia')),
                      IconButton(
                        tooltip: _hideBalance
                            ? 'Tampilkan saldo'
                            : 'Sembunyikan saldo',
                        onPressed: () =>
                            setState(() => _hideBalance = !_hideBalance),
                        icon: Icon(
                          _hideBalance
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _hideBalance ? 'Rp •••••••' : _formatRupiah(totalBalance),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ringkasan ${_formatMonth(DateTime.now())}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Pemasukan', income, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Pengeluaran', expense, Colors.red)),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard('Sisa saldo', totalBalance, Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openTransactionForm('income'),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Pemasukan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openTransactionForm('expense'),
                  icon: const Icon(Icons.remove),
                  label: const Text('Catat Pengeluaran'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Alokasi Bulan Ini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _allocationCard(
                'Kebutuhan',
                36,
                Colors.blue,
                Icons.shopping_cart,
              ),
              _allocationCard(
                'Darurat',
                18,
                Colors.red,
                Icons.medical_services,
              ),
              _allocationCard('Investasi', 18, Colors.green, Icons.trending_up),
              _allocationCard('Tabungan', 18, Colors.purple, Icons.savings),
              _allocationCard('Hiburan', 10, Colors.orange, Icons.celebration),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Transaksi Terbaru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Belum ada transaksi.')),
            )
          else
            ..._recentTransactions.map(_transactionTile),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _hideBalance ? '••••' : _formatRupiah(amount),
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allocationCard(
    String category,
    int percent,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$category ($percent%)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _hideBalance
                  ? '••••'
                  : _formatRupiah(_allocations[category] ?? 0),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    return Column(
      children: [
        _monthSelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Catat transaksi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Pemasukan'),
                            selected: _transactionType == 'income',
                            onSelected: (_) => setState(() {
                              _transactionType = 'income';
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('Pengeluaran'),
                            selected: _transactionType == 'expense',
                            onSelected: (_) => setState(() {
                              _transactionType = 'expense';
                              _selectedCategory = _suggestCategoryFromNote(
                                _noteController.text,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Nominal',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (value) {
                          if (_transactionType == 'expense') {
                            setState(() {
                              _selectedCategory = _suggestCategoryFromNote(
                                value,
                              );
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Catatan',
                          hintText: 'Contoh: transfer dari teman atau touring',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_transactionType == 'expense') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Potong dari kategori',
                            helperText: 'Otomatis dari catatan; bisa diubah.',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              const [
                                'Kebutuhan',
                                'Darurat',
                                'Investasi',
                                'Tabungan',
                                'Hiburan',
                              ].map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        ),
                      ],
                      if (_transactionType == 'income') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Pemasukan dibagi otomatis: Kebutuhan 36%, Darurat 18%, Investasi 18%, Tabungan 18%, Hiburan 10%.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saveTransaction,
                        icon: const Icon(Icons.save),
                        label: Text(
                          _transactionType == 'income'
                              ? 'Simpan Pemasukan'
                              : 'Simpan Pengeluaran',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Riwayat Transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Gagal memuat transaksi: ${snapshot.error}');
                  }
                  final transactions = snapshot.data ?? [];
                  if (transactions.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('Belum ada transaksi pada bulan ini.'),
                      ),
                    );
                  }
                  return Column(
                    children: transactions.map(_transactionTile).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthSelector() {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            _formatMonth(_selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: isCurrentMonth ? null : () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int offset) {
    final month = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (month.isAfter(currentMonth)) return;

    setState(() {
      _selectedMonth = month;
      _transactionsFuture = DatabaseHelper.instance.getTransactionsForMonth(
        month,
      );
    });
  }

  Widget _buildProfilePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    _userName.isEmpty ? '?' : _userName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _userName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama panggilan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saveProfile,
                  child: const Text('Simpan Profil'),
                ),
              ],
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Data disimpan di perangkat ini'),
            subtitle: Text(
              'SavMon belum memakai akun login atau sinkronisasi online.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _transactionTile(Map<String, Object?> transaction) {
    final type = transaction['type']?.toString() ?? 'expense';
    final isIncome = type == 'income';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final note = transaction['note']?.toString() ?? '';
    final title = transaction['title']?.toString() ?? 'Transaksi';
    final category = transaction['category']?.toString() ?? '-';
    final date = _formatDate(transaction['date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(note.isEmpty ? title : note),
        subtitle: Text(isIncome ? 'Pemasukan - $date' : '$category - $date'),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${_formatRupiah(amount)}',
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatRupiah(double amount) => 'Rp ${amount.toStringAsFixed(0)}';

  String _formatDate(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  String _formatMonth(DateTime month) {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${monthNames[month.month - 1]} ${month.year}';
  }
}
