import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODUKATHEE ADAVVU',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
          ),
        ),
      ),
      home: EMIHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EMIEntry {
  final String id;
  final String name;
  final double amount;
  final DateTime date;

  EMIEntry({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory EMIEntry.fromJson(Map<String, dynamic> json) {
    return EMIEntry(
      id: json['id'],
      name: json['name'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }
}

class EMICategory {
  final String id;
  final String name;
  List<EMIEntry> entries;

  EMICategory({required this.id, required this.name, this.entries = const []});

  double get totalAmount =>
      entries.fold(0.0, (sum, entry) => sum + entry.amount);

  double getWeeklyTotal() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    return entries
        .where(
          (entry) =>
              entry.date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              entry.date.isBefore(endOfWeek.add(Duration(days: 1))),
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double getMonthlyTotal() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth =
        (now.month < 12)
            ? DateTime(now.year, now.month + 1, 0)
            : DateTime(now.year + 1, 1, 0);

    return entries
        .where(
          (entry) =>
              entry.date.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              entry.date.isBefore(endOfMonth.add(Duration(days: 1))),
        )
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }

  factory EMICategory.fromJson(Map<String, dynamic> json) {
    return EMICategory(
      id: json['id'],
      name: json['name'],
      entries:
          (json['entries'] as List)
              .map((entry) => EMIEntry.fromJson(entry))
              .toList(),
    );
  }
}

class EMIHomePage extends StatefulWidget {
  @override
  _EMIHomePageState createState() => _EMIHomePageState();
}

class _EMIHomePageState extends State<EMIHomePage> {
  List<EMICategory> _categories = [];
  List<EMICategory> _filteredCategories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  double? _minAmountFilter;
  double? _maxAmountFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString('emiData');

      if (data != null) {
        List<dynamic> decodedData = jsonDecode(data);
        _categories =
            decodedData
                .map((category) => EMICategory.fromJson(category))
                .toList();
        _filteredCategories = List.from(_categories);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String encodedData = jsonEncode(
        _categories.map((category) => category.toJson()).toList(),
      );
      await prefs.setString('emiData', encodedData);
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _backupData() async {
    try {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/emi_backup_${DateTime.now().toIso8601String()}.json';
      final file = File(path);
      await file.writeAsString(
        jsonEncode(_categories.map((category) => category.toJson()).toList()),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup saved to $path')));
    } catch (e) {
      print('Error backing up data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create backup')));
    }
  }

  Future<void> _restoreData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        List<dynamic> decodedData = jsonDecode(contents);
        setState(() {
          _categories =
              decodedData
                  .map((category) => EMICategory.fromJson(category))
                  .toList();
          _filteredCategories = List.from(_categories);
          _saveData();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Data restored successfully')));
      }
    } catch (e) {
      print('Error restoring data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to restore data')));
    }
  }

  Future<void> _exportReport() async {
    try {
      if (await Permission.storage.request().isGranted) {
        List<List<dynamic>> csvData = [
          ['Category', 'Date', 'Amount'],
        ];

        for (var category in _categories) {
          for (var entry in category.entries) {
            csvData.add([
              category.name,
              DateFormat('yyyy-MM-dd').format(entry.date),
              entry.amount,
            ]);
          }
        }

        String csv = const ListToCsvConverter().convert(csvData);
        final directory = await getExternalStorageDirectory();
        final path =
            '${directory!.path}/emi_report_${DateTime.now().toIso8601String()}.csv';
        final file = File(path);
        await file.writeAsString(csv);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report exported to $path')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Storage permission denied')));
      }
    } catch (e) {
      print('Error exporting report: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export report')));
    }
  }

  double get totalAmount => _filteredCategories.fold(
    0.0,
    (sum, category) => sum + category.totalAmount,
  );

  double get weeklyTotal => _filteredCategories.fold(
    0.0,
    (sum, category) => sum + category.getWeeklyTotal(),
  );

  double get monthlyTotal => _filteredCategories.fold(
    0.0,
    (sum, category) => sum + category.getMonthlyTotal(),
  );

  void _addCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Add New EMI Category'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _categories.add(
          EMICategory(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result,
          ),
        );
        _filteredCategories = List.from(_categories);
        _saveData();
      });
    }
  }

  void _deleteCategory(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Category'),
            content: Text(
              'Are you sure you want to delete "${_filteredCategories[index].name}" and all its entries?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _categories.removeWhere(
          (cat) => cat.id == _filteredCategories[index].id,
        );
        _filteredCategories.removeAt(index);
        _saveData();
      });
    }
  }

  void _filterCategories() {
    setState(() {
      _filteredCategories =
          _categories.where((category) {
            bool matchesSearch = category.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
            bool matchesDate = true;
            bool matchesAmount = true;

            if (_startDateFilter != null || _endDateFilter != null) {
              matchesDate = category.entries.any((entry) {
                if (_startDateFilter != null &&
                    entry.date.isBefore(_startDateFilter!)) {
                  return false;
                }
                if (_endDateFilter != null &&
                    entry.date.isAfter(_endDateFilter!)) {
                  return false;
                }
                return true;
              });
            }

            if (_minAmountFilter != null || _maxAmountFilter != null) {
              matchesAmount = category.entries.any((entry) {
                if (_minAmountFilter != null &&
                    entry.amount < _minAmountFilter!) {
                  return false;
                }
                if (_maxAmountFilter != null &&
                    entry.amount > _maxAmountFilter!) {
                  return false;
                }
                return true;
              });
            }

            return matchesSearch && matchesDate && matchesAmount;
          }).toList();
    });
  }

  void _showFilterDialog() async {
    final minAmountController = TextEditingController();
    final maxAmountController = TextEditingController();
    DateTime? tempStartDate = _startDateFilter;
    DateTime? tempEndDate = _endDateFilter;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filter Categories'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: minAmountController,
                  decoration: InputDecoration(
                    labelText: 'Min Amount',
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: maxAmountController,
                  decoration: InputDecoration(
                    labelText: 'Max Amount',
                    prefixText: '₹',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 8),
                ListTile(
                  title: Text(
                    tempStartDate == null
                        ? 'Select Start Date'
                        : 'Start: ${DateFormat('yyyy-MM-dd').format(tempStartDate!)}',
                  ),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempStartDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      tempStartDate = picked;
                    }
                  },
                ),
                ListTile(
                  title: Text(
                    tempEndDate == null
                        ? 'Select End Date'
                        : 'End: ${DateFormat('yyyy-MM-dd').format(tempEndDate!)}',
                  ),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempEndDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      tempEndDate = picked;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minAmountFilter =
                      double.tryParse(minAmountController.text) ?? null;
                  _maxAmountFilter =
                      double.tryParse(maxAmountController.text) ?? null;
                  _startDateFilter = tempStartDate;
                  _endDateFilter = tempEndDate;
                  _filterCategories();
                });
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Odukathe Adavvu'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportReport();
              } else if (value == 'backup') {
                _backupData();
              } else if (value == 'restore') {
                _restoreData();
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(value: 'export', child: Text('Export Report')),
                  PopupMenuItem(value: 'backup', child: Text('Backup Data')),
                  PopupMenuItem(value: 'restore', child: Text('Restore Data')),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search and Filter
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _searchQuery = value;
                              _filterCategories();
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.filter_list),
                          onPressed: _showFilterDialog,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Summary Card
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildSummaryRow('Total EMI Amount:', totalAmount),
                            _buildSummaryRow('This Week:', weeklyTotal),
                            _buildSummaryRow('This Month:', monthlyTotal),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Statistics Chart
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category Distribution',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                            SizedBox(height: 16),
                            Container(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sections:
                                      _categories.map((category) {
                                        final total = totalAmount;
                                        final percentage =
                                            total > 0
                                                ? (category.totalAmount /
                                                        total) *
                                                    100
                                                : 0.0;
                                        return PieChartSectionData(
                                          color:
                                              Colors.green[(category.hashCode %
                                                          5 +
                                                      1) *
                                                  100]!,
                                          value: category.totalAmount,
                                          title:
                                              '${percentage.toStringAsFixed(1)}%',
                                          radius: 50,
                                          titleStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child:
                          _filteredCategories.isEmpty
                              ? Center(
                                child: Text(
                                  'No EMI categories yet.\nTap the + button to add one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: _filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = _filteredCategories[index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green[600],
                                        child: Text(
                                          category.name[0].toUpperCase(),
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      title: Text(
                                        category.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Total: ₹${category.totalAmount.toStringAsFixed(2)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _deleteCategory(index),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => EMIDetailPage(
                                                  category: category,
                                                  onUpdate: (updatedCategory) {
                                                    setState(() {
                                                      final idx = _categories
                                                          .indexWhere(
                                                            (cat) =>
                                                                cat.id ==
                                                                updatedCategory
                                                                    .id,
                                                          );
                                                      if (idx != -1) {
                                                        _categories[idx] =
                                                            updatedCategory;
                                                      }
                                                      _filteredCategories =
                                                          List.from(
                                                            _categories,
                                                          );
                                                      _filterCategories();
                                                      _saveData();
                                                    });
                                                  },
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: Icon(Icons.add),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.green[700])),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}

class EMIDetailPage extends StatefulWidget {
  final EMICategory category;
  final Function(EMICategory) onUpdate;

  EMIDetailPage({required this.category, required this.onUpdate});

  @override
  _EMIDetailPageState createState() => _EMIDetailPageState();
}

class _EMIDetailPageState extends State<EMIDetailPage> {
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  late EMICategory _category;
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  List<EMIEntry> _filteredEntries = [];

  @override
  void initState() {
    super.initState();
    _category = EMICategory(
      id: widget.category.id,
      name: widget.category.name,
      entries: List.from(widget.category.entries),
    );
    _filteredEntries = List.from(_category.entries);
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  void _addEntry() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    setState(() {
      _category.entries.add(
        EMIEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _category.name,
          amount: amount,
          date: _selectedDate,
        ),
      );
      _filteredEntries = List.from(_category.entries);
      _filterEntries();
      widget.onUpdate(_category);
      _amountController.clear();
    });
  }

  void _deleteEntry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Entry'),
            content: Text('Are you sure you want to delete this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _category.entries.removeWhere((entry) => entry.id == id);
        _filteredEntries = List.from(_category.entries);
        _filterEntries();
        widget.onUpdate(_category);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  void _filterEntries() {
    setState(() {
      _filteredEntries =
          _category.entries.where((entry) {
            return entry.amount.toString().contains(_searchQuery) ||
                DateFormat(
                  'yyyy-MM-dd',
                ).format(entry.date).contains(_searchQuery);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_category.name)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search entries...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterEntries();
              },
            ),
            SizedBox(height: 16),
            // Summary Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildSummaryRow('Total:', _category.totalAmount),
                    _buildSummaryRow('This Week:', _category.getWeeklyTotal()),
                    _buildSummaryRow(
                      'This Month:',
                      _category.getMonthlyTotal(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // Add new entry section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Entry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: '₹',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _addEntry,
                        icon: Icon(Icons.add),
                        label: Text('Add Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child:
                  _filteredEntries.isEmpty
                      ? Center(
                        child: Text(
                          'No entries yet.\nAdd your first entry above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _filteredEntries.length,
                        itemBuilder: (context, index) {
                          final sortedEntries = List.from(_filteredEntries)
                            ..sort((a, b) => b.date.compareTo(a.date));
                          final entry = sortedEntries[index];

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green[200],
                                child: Icon(
                                  Icons.payment,
                                  color: Colors.green[800],
                                ),
                              ),
                              title: Text(
                                '₹${entry.amount.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                DateFormat('MMM dd, yyyy').format(entry.date),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEntry(entry.id),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.green[700])),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }
}
