import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final sites = await db.getAllSites();
  final activeSites = await db.getActiveSites();
  final vendors = await db.getAllVendors();
  final expenses = await db.getAllExpenses();
  final totalExpenses = await db.getTotalExpenses();
  
  // Current month expenses
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  final monthExpenses = await db.getExpensesByDateRange(firstDayOfMonth, lastDayOfMonth);
  final monthTotal = monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);

  return DashboardStats(
    totalSites: sites.length,
    activeSites: activeSites.length,
    totalVendors: vendors.length,
    totalExpenses: totalExpenses,
    monthlyExpenses: monthTotal,
    expensesCount: expenses.length,
  );
});

enum ChartPeriod { last6Months, last12Months, last2Years }

final chartPeriodProvider = StateProvider<ChartPeriod>((ref) => ChartPeriod.last6Months);

final expenseTrendProvider = FutureProvider<List<MonthlyExpense>>((ref) async {
  final db = ref.watch(databaseProvider);
  final period = ref.watch(chartPeriodProvider);
  final allExpenses = await db.getAllExpenses();
  
  final now = DateTime.now();
  int monthsToShow;
  
  switch (period) {
    case ChartPeriod.last6Months:
      monthsToShow = 6;
      break;
    case ChartPeriod.last12Months:
      monthsToShow = 12;
      break;
    case ChartPeriod.last2Years:
      monthsToShow = 24;
      break;
  }
  
  final Map<String, double> monthlyTotals = {};
  
  // Initialize all months with 0
  for (int i = monthsToShow - 1; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('MMM yyyy').format(month);
    monthlyTotals[key] = 0.0;
  }
  
  // Aggregate expenses by month
  for (final expense in allExpenses) {
    final monthKey = DateFormat('MMM yyyy').format(expense.date);
    if (monthlyTotals.containsKey(monthKey)) {
      monthlyTotals[monthKey] = monthlyTotals[monthKey]! + expense.amount;
    }
  }
  
  // Convert to list
  return monthlyTotals.entries
      .map((e) => MonthlyExpense(month: e.key, amount: e.value))
      .toList();
});

class DashboardStats {
  final int totalSites;
  final int activeSites;
  final int totalVendors;
  final double totalExpenses;
  final double monthlyExpenses;
  final int expensesCount;

  DashboardStats({
    required this.totalSites,
    required this.activeSites,
    required this.totalVendors,
    required this.totalExpenses,
    required this.monthlyExpenses,
    required this.expensesCount,
  });
}

class MonthlyExpense {
  final String month;
  final double amount;

  MonthlyExpense({required this.month, required this.amount});
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Dashboard'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              child: const Text('Refresh'),
              onPressed: () {
                ref.invalidate(dashboardStatsProvider);
                ref.invalidate(expenseTrendProvider);
              },
            ),
          ],
        ),
      ),
      content: statsAsync.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Total Sites',
                    value: stats.totalSites.toString(),
                    subtitle: '${stats.activeSites} active',
                    icon: FluentIcons.site_scan,
                    color: Colors.blue,
                  ),
                  _StatCard(
                    title: 'Total Vendors',
                    value: stats.totalVendors.toString(),
                    subtitle: ' ',
                    icon: FluentIcons.people,
                    color: Colors.green,
                  ),
                  _StatCard(
                    title: 'This Month',
                    value: currencyFormat.format(stats.monthlyExpenses),
                    subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                    icon: FluentIcons.money,
                    color: Colors.purple,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // Expense Trend Chart
              const _ExpenseTrendChart(),
            ],
          ),
        ),
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: InfoBar(
            title: const Text('Error loading dashboard'),
            content: Text(error.toString()),
            severity: InfoBarSeverity.error,
          ),
        ),
      ),
    );
  }
}

class _ExpenseTrendChart extends ConsumerWidget {
  const _ExpenseTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(expenseTrendProvider);
    final selectedPeriod = ref.watch(chartPeriodProvider);
    final currencyFormat = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expense Trend',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                ComboBox<ChartPeriod>(
                  value: selectedPeriod,
                  items: const [
                    ComboBoxItem(
                      value: ChartPeriod.last6Months,
                      child: Text('Last 6 Months'),
                    ),
                    ComboBoxItem(
                      value: ChartPeriod.last12Months,
                      child: Text('Last 12 Months'),
                    ),
                    ComboBoxItem(
                      value: ChartPeriod.last2Years,
                      child: Text('Last 2 Years'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(chartPeriodProvider.notifier).state = value;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            trendAsync.when(
              data: (monthlyExpenses) {
                if (monthlyExpenses.isEmpty) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('No expense data available'),
                    ),
                  );
                }

                final maxAmount = monthlyExpenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
                final spots = monthlyExpenses.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.amount);
                }).toList();

                return SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxAmount > 0 ? maxAmount / 5 : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[80],
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < monthlyExpenses.length) {
                                final month = monthlyExpenses[value.toInt()].month;
                                final parts = month.split(' ');
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    parts[0], // Show only month abbreviation
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: maxAmount > 0 ? maxAmount / 5 : 1,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                currencyFormat.format(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey[80]),
                      ),
                      minX: 0,
                      maxX: (monthlyExpenses.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxAmount > 0 ? maxAmount * 1.1 : 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.blue,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withOpacity(0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              if (spot.spotIndex >= 0 && spot.spotIndex < monthlyExpenses.length) {
                                final monthData = monthlyExpenses[spot.spotIndex];
                                return LineTooltipItem(
                                  '${monthData.month}\n${NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(monthData.amount)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: ProgressRing()),
              ),
              error: (error, stack) => SizedBox(
                height: 300,
                child: Center(
                  child: InfoBar(
                    title: const Text('Error loading chart data'),
                    content: Text(error.toString()),
                    severity: InfoBarSeverity.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final AccentColor color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.light,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24, color: color.lightest),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: FluentTheme.of(context).typography.title,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.grey[100],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}