import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'sites_screen.dart';
import 'expenses_screen.dart';
import 'vendors_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<NavigationPaneItem> _items = [
  
   PaneItem(
      icon: const Icon(FluentIcons.money),
      title: const Text('Expenses'),
      body: const ExpensesScreen(),
    ),
    PaneItem(
      icon: const Icon(FluentIcons.real_estate),
      title: const Text('Sites'),
      body: const SitesScreen(),
    ),
    PaneItem(
      icon: const Icon(FluentIcons.people),
      title: const Text('Vendors'),
      body: const VendorsScreen(),
    ),
    PaneItem(
      icon: const Icon(FluentIcons.chart),
      title: const Text('Reports'),
      body: const ReportsScreen(),
    ),
      PaneItem(
      icon: const Icon(FluentIcons.view_dashboard),
      title: const Text('Dashboard'),
      body: const DashboardScreen(),
    ),
  ];

  final List<NavigationPaneItem> _footerItems = [
    PaneItem(
      icon: const Icon(FluentIcons.settings),
      title: const Text('Settings'),
      body: const SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        selected: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        displayMode: PaneDisplayMode.auto,
        items: _items,
        footerItems: _footerItems,
      ),
    );
  }
}