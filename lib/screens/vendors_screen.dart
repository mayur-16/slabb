import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
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
        await displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Vendor deleted successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    }
  }

  void _showAddEditDialog({Vendor? vendor}) {
    final nameController = TextEditingController(text: vendor?.name ?? '');
    final contactPersonController = TextEditingController(text: vendor?.contactPerson ?? '');
    final phoneController = TextEditingController(text: vendor?.phone ?? '');
    final emailController = TextEditingController(text: vendor?.email ?? '');
    final addressController = TextEditingController(text: vendor?.address ?? '');

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
                  label: 'Contact Person',
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
                await displayInfoBar(context, builder: (context, close) {
                  return const InfoBar(
                    title: Text('Vendor name is required'),
                    severity: InfoBarSeverity.warning,
                  );
                });
                return;
              }

              final db = ref.read(databaseProvider);
              
              if (vendor == null) {
                await db.insertVendor(VendorsCompanion(
                  name: drift.Value(nameController.text.trim()),
                  contactPerson: drift.Value(contactPersonController.text.trim()),
                  phone: drift.Value(phoneController.text.trim()),
                  email: drift.Value(emailController.text.trim()),
                  address: drift.Value(addressController.text.trim()),
                ));
              } else {
                await db.update(db.vendors).replace(
                  VendorsCompanion(
                    id: drift.Value(vendor.id),
                    name: drift.Value(nameController.text.trim()),
                    contactPerson: drift.Value(contactPersonController.text.trim()),
                    phone: drift.Value(phoneController.text.trim()),
                    email: drift.Value(emailController.text.trim()),
                    address: drift.Value(addressController.text.trim()),
                    createdAt: drift.Value(vendor.createdAt),
                  ),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                await displayInfoBar(context, builder: (context, close) {
                  return InfoBar(
                    title: Text(vendor == null ? 'Vendor added' : 'Vendor updated'),
                    severity: InfoBarSeverity.success,
                  );
                });
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
                      color: Colors.blue.light.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:  Icon(FluentIcons.people, color: Colors.blue),
                  ),
                  title: Text(vendor.name),
                  subtitle: vendor.phone != null || vendor.email != null
                    ? Text('${vendor.phone ?? ""} ${vendor.email ?? ""}')
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