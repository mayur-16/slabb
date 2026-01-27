import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
              onPressed: () => ref.invalidate(dashboardStatsProvider),
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
              
              const SizedBox(height: 20),
             
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