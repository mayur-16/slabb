import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';

final vendorsProvider = StreamProvider<List<Vendor>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.vendors).watch();
});

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  void _showVendorDetails(Vendor vendor) async {
    final db = ref.read(databaseProvider);

    // Get all expenses for this vendor
    final allExpenses = await db.getAllExpenses();
    final vendorExpenses = allExpenses
        .where((e) => e.vendorId == vendor.id)
        .toList();
    final totalExpenses = vendorExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(vendor.name),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Info
              if (vendor.contactPerson != null &&
                  vendor.contactPerson!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(FluentIcons.contact, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(vendor.contactPerson!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (vendor.phone != null && vendor.phone!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(FluentIcons.phone, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(vendor.phone!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (vendor.email != null && vendor.email!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(FluentIcons.mail, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(vendor.email!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (vendor.address != null && vendor.address!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(FluentIcons.location, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(vendor.address!)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  const Icon(FluentIcons.calendar, size: 16),
                  const SizedBox(width: 8),
                  Text('Added: ${dateFormat.format(vendor.createdAt)}'),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Transaction Summary
              Text(
                'Transaction Summary',
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
                          'Total Paid',
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
                          '${vendorExpenses.length}',
                          style: FluentTheme.of(context).typography.title,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (vendorExpenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recent Transactions',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: vendorExpenses.length > 5
                        ? 5
                        : vendorExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = vendorExpenses[index];
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
                if (vendorExpenses.length > 5)
                  Text(
                    '... and ${vendorExpenses.length - 5} more',
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
              _showAddEditDialog(vendor: vendor);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Vendor'),
        content: Text(
          'Are you sure you want to delete "${vendor.name}"?\n\nThis action cannot be undone.',
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
      await db.deleteVendor(vendor.id);

      if (context.mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) {
            return const InfoBar(
              title: Text('Vendor deleted successfully'),
              severity: InfoBarSeverity.success,
            );
          },
        );
      }
    }
  }

  void _showAddEditDialog({Vendor? vendor}) {
    final nameController = TextEditingController(text: vendor?.name ?? '');
    final contactPersonController = TextEditingController(
      text: vendor?.contactPerson ?? '',
    );
    final phoneController = TextEditingController(text: vendor?.phone ?? '');
    final emailController = TextEditingController(text: vendor?.email ?? '');
    final addressController = TextEditingController(
      text: vendor?.address ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(vendor == null ? 'Add New Vendor' : 'Edit Vendor'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLabel(
                  label: 'Vendor Name *',
                  child: TextBox(
                    controller: nameController,
                    placeholder: 'Enter vendor name',
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Contact Person Name',
                  child: TextBox(
                    controller: contactPersonController,
                    placeholder: 'Enter contact person name',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: 'Phone',
                        child: TextBox(
                          controller: phoneController,
                          placeholder: 'Phone number',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InfoLabel(
                        label: 'Email',
                        child: TextBox(
                          controller: emailController,
                          placeholder: 'Email address',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Address',
                  child: TextBox(
                    controller: addressController,
                    placeholder: 'Enter address',
                    maxLines: 3,
                  ),
                ),
              ],
            ),
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
                      title: Text('Vendor name is required'),
                      severity: InfoBarSeverity.warning,
                    );
                  },
                );
                return;
              }

              final db = ref.read(databaseProvider);

              if (vendor == null) {
                await db.insertVendor(
                  VendorsCompanion(
                    name: drift.Value(nameController.text.trim()),
                    contactPerson: drift.Value(
                      contactPersonController.text.trim(),
                    ),
                    phone: drift.Value(phoneController.text.trim()),
                    email: drift.Value(emailController.text.trim()),
                    address: drift.Value(addressController.text.trim()),
                  ),
                );
              } else {
                await db
                    .update(db.vendors)
                    .replace(
                      VendorsCompanion(
                        id: drift.Value(vendor.id),
                        name: drift.Value(nameController.text.trim()),
                        contactPerson: drift.Value(
                          contactPersonController.text.trim(),
                        ),
                        phone: drift.Value(phoneController.text.trim()),
                        email: drift.Value(emailController.text.trim()),
                        address: drift.Value(addressController.text.trim()),
                        createdAt: drift.Value(vendor.createdAt),
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
                        vendor == null ? 'Vendor added' : 'Vendor updated',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Vendors'),
        commandBar: FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 16),
              SizedBox(width: 8),
              Text('Add Vendor'),
            ],
          ),
          onPressed: () => _showAddEditDialog(),
        ),
      ),
      content: vendorsAsync.when(
        data: (vendors) {
          if (vendors.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.people, size: 64),
                  SizedBox(height: 16),
                  Text('No vendors found'),
                  SizedBox(height: 8),
                  Text('Click "Add Vendor" to add your first vendor'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.light.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(FluentIcons.people, color: Colors.blue),
                  ),
                  title: Text(vendor.name),
                  subtitle: vendor.phone != null && vendor.phone!.isNotEmpty
                      ? Text(vendor.phone!)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit),
                        onPressed: () => _showAddEditDialog(vendor: vendor),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: () => _showDeleteConfirmation(vendor),
                      ),
                    ],
                  ),
                  onPressed: () => _showVendorDetails(vendor),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, stack) => Center(
          child: InfoBar(
            title: const Text('Error loading vendors'),
            content: Text(error.toString()),
            severity: InfoBarSeverity.error,
          ),
        ),
      ),
    );
  }
}
