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
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  Map<String, double> _allocations = {
    'Kebutuhan': 0.0,
    'Darurat': 0.0,
    'Investasi': 0.0,
    'Tabungan': 0.0,
    'Hiburan': 0.0,
  };

  int _selectedIndex = 0;
  DateTime _selectedHistoryMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selectedCategory = 'Kebutuhan';
  late Future<List<Map<String, Object?>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historyFuture = DatabaseHelper.instance.getExpenseHistoryForMonth(_selectedHistoryMonth);
    _loadData();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _expenseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }
  Future<void> _loadData() async {
    final monthWasReset =
        await DatabaseHelper.instance.resetAllocationsForNewMonth();
    final data = await DatabaseHelper.instance.getAllocations();
    if (!mounted) return;

    setState(() => _allocations = data);
    if (monthWasReset) {
      _showMessage(
        'Bulan baru: saldo alokasi direset. Masukkan saldo bulan ini.',
      );
    }
  }

  Future<void> _calculateAllocation() async {
    final total = double.tryParse(_balanceController.text.trim()) ?? 0;
    if (total <= 0) {
      _showMessage('Masukkan total saldo lebih besar dari 0.');
      return;
    }

    await DatabaseHelper.instance.saveAllocations(total);
    await _loadData();
    if (!mounted) return;

    _balanceController.clear();
    FocusScope.of(context).unfocus();
    _showMessage('Saldo berhasil dialokasikan dan disimpan.');
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(
      _expenseController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      _showMessage('Masukkan nominal pengeluaran lebih besar dari 0.');
      return;
    }

    try {
      await DatabaseHelper.instance.addExpense(
        _selectedCategory,
        amount,
        note: _noteController.text.trim(),
      );
      await _loadData();
      if (!mounted) return;

      final currentDate = DateTime.now();
      final currentMonth = DateTime(currentDate.year, currentDate.month);
      setState(() {
        _selectedHistoryMonth = currentMonth;
        _historyFuture = DatabaseHelper.instance.getExpenseHistoryForMonth(currentMonth);
      });
      _expenseController.clear();
      _noteController.clear();
      FocusScope.of(context).unfocus();
      _showMessage('Pengeluaran berhasil dicatat.');
    } catch (error) {
      await _loadData();
      _showMessage('Gagal mencatat pengeluaran: $error');
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildAllocationPage(),
      _buildExpensePage(),
      _buildHistoryPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SavMon', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Alokasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Catat',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Masukkan Total Saldo Baru',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Contoh: 1000000',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _calculateAllocation,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Alokasikan Dana',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Alokasi Tabungan Anda:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildAllocationCard(
                'Kebutuhan (36%)',
                _allocations['Kebutuhan'] ?? 0,
                Colors.blue,
                Icons.shopping_cart,
              ),
              _buildAllocationCard(
                'Darurat (18%)',
                _allocations['Darurat'] ?? 0,
                Colors.red,
                Icons.medical_services,
              ),
              _buildAllocationCard(
                'Investasi (18%)',
                _allocations['Investasi'] ?? 0,
                Colors.green,
                Icons.trending_up,
              ),
              _buildAllocationCard(
                'Tabungan (18%)',
                _allocations['Tabungan'] ?? 0,
                Colors.purple,
                Icons.savings,
              ),
              _buildAllocationCard(
                'Hiburan (10%)',
                _allocations['Hiburan'] ?? 0,
                Colors.orange,
                Icons.celebration,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Catat Pengeluaran',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _expenseController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nominal pengeluaran',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = _suggestCategoryFromNote(value);
                    });
                  },
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    hintText: 'Contoh: servis motor atau beli jajan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Potong dari kategori',
                    helperText: 'Dipilih dari catatan; bisa diubah manual.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
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
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Pengeluaran'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryPage() {
    final now = DateTime.now();
    final isCurrentMonth = _selectedHistoryMonth.year == now.year &&
        _selectedHistoryMonth.month == now.month;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: () => _changeHistoryMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _formatMonth(_selectedHistoryMonth),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: isCurrentMonth ? null : () => _changeHistoryMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Gagal memuat riwayat: ${snapshot.error}'),
                );
              }

              final expenses = snapshot.data ?? [];
              if (expenses.isEmpty) {
                return const Center(
                  child: Text('Belum ada pengeluaran pada bulan ini.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
                  final category = expense['category']?.toString() ?? '-';
                  final title = expense['title']?.toString() ?? 'Pengeluaran';
                  final note = expense['note']?.toString() ?? '';
                  final date = _formatDate(expense['date']);

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.remove_circle_outline),
                      ),
                      title: Text(note.isEmpty ? title : note),
                      subtitle: Text('$category - $date'),
                      trailing: Text(
                        '- Rp ${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _changeHistoryMonth(int offset) {
    final month = DateTime(
      _selectedHistoryMonth.year,
      _selectedHistoryMonth.month + offset,
    );
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (month.isAfter(currentMonth)) return;

    setState(() {
      _selectedHistoryMonth = month;
      _historyFuture = DatabaseHelper.instance.getExpenseHistoryForMonth(month);
    });
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

  Widget _buildAllocationCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Rp ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}












