import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.expenses).watch();
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  void _showDeleteConfirmation(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete this expense?\n\n'
          'Description: ${expense.description}\n'
          'Amount: ₹${expense.amount.toStringAsFixed(2)}\n\n'
          'This action cannot be undone.',
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
      await db.deleteExpense(expense.id);
      
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Expense deleted successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    }
  }

  void _showAddEditDialog({Expense? expense}) async {
    final db = ref.read(databaseProvider);
    final sites = await db.getAllSites();
    final vendors = await db.getAllVendors();
    final categories = await db.getAllCategories();

    if (!mounted) return;

    final descriptionController = TextEditingController(text: expense?.description ?? '');
    final amountController = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );
    final billNumberController = TextEditingController(text: expense?.billNumber ?? '');
    final remarksController = TextEditingController(text: expense?.remarks ?? '');
    
    int? selectedSiteId = expense?.siteId;
    int? selectedVendorId = expense?.vendorId;
    int? selectedCategoryId = expense?.categoryId;
    DateTime selectedDate = expense?.date ?? DateTime.now();
    String paymentMode = expense?.paymentMode ?? 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ContentDialog(
          title: Text(expense == null ? 'Add New Expense' : 'Edit Expense'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: 'Site *',
                    child: ComboBox<int>(
                      value: selectedSiteId,
                      placeholder: const Text('Select site'),
                      items: sites.map((site) => ComboBoxItem(
                        value: site.id,
                        child: Text(site.name),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedSiteId = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Description *',
                    child: TextBox(
                      controller: descriptionController,
                      placeholder: 'Enter expense description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: 'Amount *',
                          child: TextBox(
                            controller: amountController,
                            placeholder: '0.00',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text('₹'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InfoLabel(
                          label: 'Date *',
                          child: DatePicker(
                            selected: selectedDate,
                            onChanged: (date) => setState(() => selectedDate = date),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: 'Vendor',
                          child: ComboBox<int>(
                            value: selectedVendorId,
                            placeholder: const Text('Select vendor'),
                            items: vendors.map((vendor) => ComboBoxItem(
                              value: vendor.id,
                              child: Text(vendor.name),
                            )).toList(),
                            onChanged: (value) => setState(() => selectedVendorId = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InfoLabel(
                          label: 'Category',
                          child: ComboBox<int>(
                            value: selectedCategoryId,
                            placeholder: const Text('Select category'),
                            items: categories.map((cat) => ComboBoxItem(
                              value: cat.id,
                              child: Text(cat.name),
                            )).toList(),
                            onChanged: (value) => setState(() => selectedCategoryId = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: 'Payment Mode',
                          child: ComboBox<String>(
                            value: paymentMode,
                            items: const [
                              ComboBoxItem(value: 'Cash', child: Text('Cash')),
                              ComboBoxItem(value: 'Cheque', child: Text('Cheque')),
                              ComboBoxItem(value: 'Online', child: Text('Online')),
                              ComboBoxItem(value: 'UPI', child: Text('UPI')),
                              ComboBoxItem(value: 'Card', child: Text('Card')),
                            ],
                            onChanged: (value) => setState(() => paymentMode = value ?? 'Cash'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InfoLabel(
                          label: 'Bill Number',
                          child: TextBox(
                            controller: billNumberController,
                            placeholder: 'Optional',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Remarks',
                    child: TextBox(
                      controller: remarksController,
                      placeholder: 'Optional',
                      maxLines: 2,
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
                if (selectedSiteId == null || descriptionController.text.trim().isEmpty || amountController.text.trim().isEmpty) {
                  await displayInfoBar(context, builder: (context, close) {
                    return const InfoBar(
                      title: Text('Please fill all required fields'),
                      severity: InfoBarSeverity.warning,
                    );
                  });
                  return;
                }

                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  await displayInfoBar(context, builder: (context, close) {
                    return const InfoBar(
                      title: Text('Invalid amount'),
                      severity: InfoBarSeverity.warning,
                    );
                  });
                  return;
                }

                if (expense == null) {
                  await db.insertExpense(ExpensesCompanion(
                    siteId: drift.Value(selectedSiteId!),
                    vendorId: drift.Value(selectedVendorId),
                    categoryId: drift.Value(selectedCategoryId),
                    description: drift.Value(descriptionController.text.trim()),
                    amount: drift.Value(amount),
                    date: drift.Value(selectedDate),
                    paymentMode: drift.Value(paymentMode),
                    billNumber: drift.Value(billNumberController.text.trim()),
                    remarks: drift.Value(remarksController.text.trim()),
                  ));
                } else {
                  // For updates, use toCompanion() and update method
                  await db.update(db.expenses).replace(
                    ExpensesCompanion(
                      id: drift.Value(expense.id),
                      siteId: drift.Value(selectedSiteId!),
                      vendorId: drift.Value(selectedVendorId),
                      categoryId: drift.Value(selectedCategoryId),
                      description: drift.Value(descriptionController.text.trim()),
                      amount: drift.Value(amount),
                      date: drift.Value(selectedDate),
                      paymentMode: drift.Value(paymentMode),
                      billNumber: drift.Value(billNumberController.text.trim()),
                      remarks: drift.Value(remarksController.text.trim()),
                      createdAt: drift.Value(expense.createdAt),
                    ),
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  await displayInfoBar(context, builder: (context, close) {
                    return InfoBar(
                      title: Text(expense == null ? 'Expense added' : 'Expense updated'),
                      severity: InfoBarSeverity.success,
                    );
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Expenses'),
        commandBar: FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 16),
              SizedBox(width: 8),
              Text('Add Expense'),
            ],
          ),
          onPressed: () => _showAddEditDialog(),
        ),
      ),
      content: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.money, size: 64),
                  SizedBox(height: 16),
                  Text('No expenses recorded'),
                  SizedBox(height: 8),
                  Text('Click "Add Expense" to record your first expense'),
                ],
              ),
            );
          }

          // Sort by date descending
          final sortedExpenses = List<Expense>.from(expenses)
            ..sort((a, b) => b.date.compareTo(a.date));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedExpenses.length,
            itemBuilder: (context, index) {
              final expense = sortedExpenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.light.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:  Icon(FluentIcons.money, color: Colors.orange),
                  ),
                  title: Text(expense.description),
                  subtitle: Text(
                    '${dateFormat.format(expense.date)} • ${expense.paymentMode ?? "Cash"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyFormat.format(expense.amount),
                        style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(FluentIcons.edit),
                        onPressed: () => _showAddEditDialog(expense: expense),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: () => _showDeleteConfirmation(expense),
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
            title: const Text('Error loading expenses'),
            content: Text(error.toString()),
            severity: InfoBarSeverity.error,
          ),
        ),
      ),
    );
  }
}