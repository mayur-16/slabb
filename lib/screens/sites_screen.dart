import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';

final sitesProvider = StreamProvider<List<Site>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.sites).watch();
});

class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  void _showSiteDetails(Site site) async {
    final db = ref.read(databaseProvider);
    final totalExpenses = await db.getTotalExpensesBySite(site.id);
    final expenses = await db.getExpensesBySite(site.id);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(site.name),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site Info
              if (site.location != null && site.location!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(FluentIcons.location, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(site.location!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (site.description != null && site.description!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(FluentIcons.info, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(site.description!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  const Icon(FluentIcons.calendar, size: 16),
                  const SizedBox(width: 8),
                  Text('Created: ${dateFormat.format(site.createdAt)}'),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Expense Summary
              Text(
                'Expense Summary',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.light.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.light),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalExpenses),
                          style: FluentTheme.of(
                            context,
                          ).typography.title?.copyWith(color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Transactions',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expenses.length}',
                          style: FluentTheme.of(context).typography.title,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (expenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recent Expenses',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: expenses.length > 5 ? 5 : expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return ListTile(
                        title: Text(expense.description),
                        subtitle: Text(dateFormat.format(expense.date)),
                        trailing: Text(
                          currencyFormat.format(expense.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                if (expenses.length > 5)
                  Text(
                    '... and ${expenses.length - 5} more',
                    style: FluentTheme.of(context).typography.caption,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          Button(
            child: const Text('Close'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          FilledButton(
            child: const Text('Edit'),
            onPressed: () {
              Navigator.pop(context);
              _showAddEditDialog(site: site);
            },
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({Site? site}) {
    final nameController = TextEditingController(text: site?.name ?? '');
    final locationController = TextEditingController(
      text: site?.location ?? '',
    );
    final descriptionController = TextEditingController(
      text: site?.description ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ContentDialog(
          title: Text(site == null ? 'Add New Site' : 'Edit Site'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLabel(
                  label: 'Site Name *',
                  child: TextBox(
                    controller: nameController,
                    placeholder: 'Enter site name',
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Location',
                  child: TextBox(
                    controller: locationController,
                    placeholder: 'Enter location',
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Description',
                  child: TextBox(
                    controller: descriptionController,
                    placeholder: 'Enter description',
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Save'),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  await displayInfoBar(
                    context,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text('Site name is required'),
                        severity: InfoBarSeverity.warning,
                      );
                    },
                  );
                  return;
                }

                final db = ref.read(databaseProvider);

                if (site == null) {
                  // Add new
                  await db.insertSite(
                    SitesCompanion(
                      name: drift.Value(nameController.text.trim()),
                      location: drift.Value(locationController.text.trim()),
                      description: drift.Value(
                        descriptionController.text.trim(),
                      ),
                    ),
                  );
                } else {
                  // Update existing
                  await db
                      .update(db.sites)
                      .replace(
                        SitesCompanion(
                          id: drift.Value(site.id),
                          name: drift.Value(nameController.text.trim()),
                          location: drift.Value(locationController.text.trim()),
                          description: drift.Value(
                            descriptionController.text.trim(),
                          ),
                          createdAt: drift.Value(site.createdAt),
                        ),
                      );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  await displayInfoBar(
                    context,
                    builder: (context, close) {
                      return InfoBar(
                        title: Text(
                          site == null
                              ? 'Site added successfully'
                              : 'Site updated successfully',
                        ),
                        severity: InfoBarSeverity.success,
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Site site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Site'),
        content: Text(
          'Are you sure you want to delete "${site.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.deleteSite(site.id);

      if (context.mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) {
            return const InfoBar(
              title: Text('Site deleted successfully'),
              severity: InfoBarSeverity.success,
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Sites'),
        commandBar: FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 16),
              SizedBox(width: 8),
              Text('Add Site'),
            ],
          ),
          onPressed: () => _showAddEditDialog(),
        ),
      ),
      content: sitesAsync.when(
        data: (sites) {
          if (sites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.real_estate, size: 64),
                  SizedBox(height: 16),
                  Text('No sites found'),
                  SizedBox(height: 8),
                  Text('Click "Add Site" to create your first site'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sites.length,
            itemBuilder: (context, index) {
              final site = sites[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onPressed: () => _showSiteDetails(site),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.light.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(FluentIcons.real_estate, color: Colors.green),
                  ),
                  title: Text(site.name),
                  subtitle: site.location != null ? Text(site.location!) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit),
                        onPressed: () => _showAddEditDialog(site: site),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: () => _showDeleteConfirmation(site),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: InfoBar(
            title: const Text('Error loading sites'),
            content: Text(error.toString()),
            severity: InfoBarSeverity.error,
          ),
        ),
      ),
    );
  }
}
