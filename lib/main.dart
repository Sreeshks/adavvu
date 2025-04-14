import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODUKATHEE ADAVVU',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(backgroundColor: Colors.indigo, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 73, 80, 115),
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
  bool _isLoading = true;

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

  double get totalAmount =>
      _categories.fold(0.0, (sum, category) => sum + category.totalAmount);

  double get weeklyTotal =>
      _categories.fold(0.0, (sum, category) => sum + category.getWeeklyTotal());

  double get monthlyTotal => _categories.fold(
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
              'Are you sure you want to delete "${_categories[index].name}" and all its entries?',
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
        _categories.removeAt(index);
        _saveData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Odukathe adavvu'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    Card(
                      color: Colors.indigo[50],
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
                                color: Colors.indigo[800],
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
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child:
                          _categories.isEmpty
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
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.indigo,
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
                                                      _categories[index] =
                                                          updatedCategory;
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
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.indigo[700]),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
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
  late EMICategory _category;
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the category
    _category = EMICategory(
      id: widget.category.id,
      name: widget.category.name,
      entries: List.from(widget.category.entries),
    );
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
              primary: Colors.indigo,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_category.name)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              color: Colors.indigo[50],
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
                        color: Colors.indigo[800],
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

            // Entries List
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child:
                  _category.entries.isEmpty
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
                        itemCount: _category.entries.length,
                        itemBuilder: (context, index) {
                          // Sort entries by date, most recent first
                          final sortedEntries = List.from(_category.entries)
                            ..sort((a, b) => b.date.compareTo(a.date));
                          final entry = sortedEntries[index];

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo[200],
                                child: Icon(
                                  Icons.payment,
                                  color: Colors.indigo[800],
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
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.indigo[700]),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
        ],
      ),
    );
  }
}
