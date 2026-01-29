import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';

enum ReportType { bySite, byVendor, byCategory, byMonth, byPaymentMode }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportType _selectedReport = ReportType.bySite;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<Map<String, double>> _generateReport() async {
    final db = ref.read(databaseProvider);
    List<Expense> expenses;

    // Filter by date range if specified
    if (_startDate != null && _endDate != null) {
      expenses = await db.getExpensesByDateRange(_startDate!, _endDate!);
    } else {
      expenses = await db.getAllExpenses();
    }

    final Map<String, double> report = {};

    switch (_selectedReport) {
      case ReportType.bySite:
        final sites = await db.getAllSites();
        final sitesMap = {for (var s in sites) s.id: s.name};

        for (var expense in expenses) {
          final siteName = sitesMap[expense.siteId] ?? 'Unknown Site';
          report[siteName] = (report[siteName] ?? 0) + expense.amount;
        }
        break;

      case ReportType.byVendor:
        final vendors = await db.getAllVendors();
        final vendorsMap = {for (var v in vendors) v.id: v.name};

        for (var expense in expenses) {
          if (expense.vendorId != null) {
            final vendorName = vendorsMap[expense.vendorId] ?? 'Unknown Vendor';
            report[vendorName] = (report[vendorName] ?? 0) + expense.amount;
          } else {
            report['No Vendor'] = (report['No Vendor'] ?? 0) + expense.amount;
          }
        }
        break;

      case ReportType.byCategory:
        final categories = await db.getAllCategories();
        final categoriesMap = {for (var c in categories) c.id: c.name};

        for (var expense in expenses) {
          if (expense.categoryId != null) {
            final categoryName =
                categoriesMap[expense.categoryId] ?? 'Unknown Category';
            report[categoryName] = (report[categoryName] ?? 0) + expense.amount;
          } else {
            report['Uncategorized'] =
                (report['Uncategorized'] ?? 0) + expense.amount;
          }
        }
        break;

      case ReportType.byMonth:
        for (var expense in expenses) {
          final monthYear = DateFormat('MMM yyyy').format(expense.date);
          report[monthYear] = (report[monthYear] ?? 0) + expense.amount;
        }
        break;

      case ReportType.byPaymentMode:
        for (var expense in expenses) {
          final mode = expense.paymentMode ?? 'Not Specified';
          report[mode] = (report[mode] ?? 0) + expense.amount;
        }
        break;
    }

    // Sort by amount descending
    final sortedEntries = report.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - 1, 1);
      _endDate = DateTime(now.year, now.month, 0);
    });
  }

  void _setThisYear() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Reports & Analytics'),
        commandBar: Button(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 14),
              SizedBox(width: 8),
              Text('Refresh'),
            ],
          ),
          onPressed: () => setState(() {}),
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    const SizedBox(height: 16),
                
                    // Report Type Selection
                    Row(
                      children: [
                        Expanded(
                          child: InfoLabel(
                            label: 'Report Type',
                            child: ComboBox<ReportType>(
                              value: _selectedReport,
                              items: const [
                                ComboBoxItem(
                                  value: ReportType.bySite,
                                  child: Text('By Site'),
                                ),
                                ComboBoxItem(
                                  value: ReportType.byVendor,
                                  child: Text('By Vendor'),
                                ),
                                ComboBoxItem(
                                  value: ReportType.byCategory,
                                  child: Text('By Category'),
                                ),
                                ComboBoxItem(
                                  value: ReportType.byMonth,
                                  child: Text('By Month'),
                                ),
                                ComboBoxItem(
                                  value: ReportType.byPaymentMode,
                                  child: Text('By Payment Mode'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedReport = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                
                    // Date Range
                    Text(
                      'Date Range',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    const SizedBox(height: 12),
                
                    Row(
                      children: [
                        InfoLabel(
                          label: 'Start Date',
                          child: DatePicker(
                            selected: _startDate,
                            onChanged: (date) =>
                                setState(() => _startDate = date),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InfoLabel(
                          label: 'End Date',
                          child: DatePicker(
                            selected: _endDate,
                            onChanged: (date) =>
                                setState(() => _endDate = date),
                          ),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 14),
                
                    // Quick date filters
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Button(
                          onPressed: _setThisMonth,
                          child: const Text('This Month'),
                        ),
                        Button(
                          onPressed: _setLastMonth,
                          child: const Text('Last Month'),
                        ),
                        Button(
                          onPressed: _setThisYear,
                          child: const Text('This Year'),
                        ),
                      ],
                    ),
                
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 22),
                    Button(
                      onPressed: _clearDateFilter,
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.all(
                          Colors.red.lighter,
                        ),
                      ),
                      child: Text('Clear Filter'),
                    ),
                  ],
                ),
              ),
            ),
                
            const SizedBox(height: 24),
                
            // Report Results
            FutureBuilder<Map<String, double>>(
              future: _generateReport(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 300,
                    child: const Center(child: ProgressRing()));
                }
              
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 300,
                    child: Center(
                      child: InfoBar(
                        title: const Text('Error generating report'),
                        content: Text(snapshot.error.toString()),
                        severity: InfoBarSeverity.error,
                      ),
                    ),
                  );
                }
              
                final report = snapshot.data ?? {};
              
                if (report.isEmpty) {
                  return SizedBox(
                    height: 300,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.chart, size: 64),
                          SizedBox(height: 16),
                          Text('No data available for selected filters'),
                        ],
                      ),
                    ),
                  );
                }
              
                final total = report.values.fold<double>(
                  0,
                  (sum, val) => sum + val,
                );
              
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Report Results',
                              style: FluentTheme.of(
                                context,
                              ).typography.subtitle,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.light.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Total: ${currencyFormat.format(total)}',
                                style: FluentTheme.of(context)
                                    .typography
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      ListView.builder(
                        shrinkWrap: true,  
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: report.length,
                        itemBuilder: (context, index) {
                          final entry = report.entries.elementAt(index);
                          final percentage = (entry.value / total * 100);
                                    
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: FluentTheme.of(
                                          context,
                                        ).typography.bodyStrong,
                                      ),
                                    ),
                                    Text(
                                      currencyFormat.format(entry.value),
                                      style: FluentTheme.of(context)
                                          .typography
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ProgressBar(value: percentage),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: FluentTheme.of(
                                        context,
                                      ).typography.caption,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
