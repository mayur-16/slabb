import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../database/database.dart';

// Filter state providers
final expensePageProvider = StateProvider<int>((ref) => 0);
final expensePageSizeProvider = StateProvider<int>((ref) => 50);
final expenseStartDateProvider = StateProvider<DateTime?>((ref) => null);
final expenseEndDateProvider = StateProvider<DateTime?>((ref) => null);
final expenseVendorFilterProvider = StateProvider<int?>((ref) => null);

// Paginated and filtered expenses provider
final paginatedExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  final page = ref.watch(expensePageProvider);
  final pageSize = ref.watch(expensePageSizeProvider);
  final startDate = ref.watch(expenseStartDateProvider);
  final endDate = ref.watch(expenseEndDateProvider);
  final vendorFilter = ref.watch(expenseVendorFilterProvider);

  var query = db.select(db.expenses);

  // Apply date range filter
  if (startDate != null && endDate != null) {
    query = query..where((e) => e.date.isBetweenValues(startDate, endDate));
  }

  // Apply vendor filter
  if (vendorFilter != null) {
    query = query..where((e) => e.vendorId.equals(vendorFilter));
  }

  // Apply sorting and pagination
  query = query
    ..orderBy([(e) => drift.OrderingTerm.desc(e.date)])
    ..limit(pageSize, offset: page * pageSize);

  return query.watch();
});

// Total count provider for pagination
final totalExpensesCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final startDate = ref.watch(expenseStartDateProvider);
  final endDate = ref.watch(expenseEndDateProvider);
  final vendorFilter = ref.watch(expenseVendorFilterProvider);

  var query = db.selectOnly(db.expenses)..addColumns([db.expenses.id.count()]);

  // Apply same filters as main query
  if (startDate != null && endDate != null) {
    query = query..where(db.expenses.date.isBetweenValues(startDate, endDate));
  }

  if (vendorFilter != null) {
    query = query..where(db.expenses.vendorId.equals(vendorFilter));
  }

  final result = await query.getSingle();
  return result.read(db.expenses.id.count()) ?? 0;
});

// Total amount provider
final totalExpensesAmountProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  final startDate = ref.watch(expenseStartDateProvider);
  final endDate = ref.watch(expenseEndDateProvider);
  final vendorFilter = ref.watch(expenseVendorFilterProvider);

  var query = db.selectOnly(db.expenses)
    ..addColumns([db.expenses.amount.sum()]);

  // Apply same filters
  if (startDate != null && endDate != null) {
    query = query..where(db.expenses.date.isBetweenValues(startDate, endDate));
  }

  if (vendorFilter != null) {
    query = query..where(db.expenses.vendorId.equals(vendorFilter));
  }

  final result = await query.getSingle();
  return result.read(db.expenses.amount.sum()) ?? 0.0;
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  void _showExpenseDetails(Expense expense) async {
    final db = ref.read(databaseProvider);
    final sites = await db.getAllSites();
    final vendors = await db.getAllVendors();
    final categories = await db.getAllCategories();

    final sitesMap = {for (var s in sites) s.id: s.name};
    final vendorsMap = {for (var v in vendors) v.id: v.name};
    final categoriesMap = {for (var c in categories) c.id: c.name};

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Expense Details'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.light.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.light),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    Text(
                      currencyFormat.format(expense.amount),
                      style: FluentTheme.of(context).typography.title?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details
              _detailRow(
                FluentIcons.real_estate,
                'Site',
                sitesMap[expense.siteId] ?? 'Unknown',
              ),
              _detailRow(FluentIcons.edit, 'Description', expense.description),
              _detailRow(
                FluentIcons.calendar,
                'Date',
                dateFormat.format(expense.date),
              ),

              if (expense.vendorId != null)
                _detailRow(
                  FluentIcons.people,
                  'Vendor',
                  vendorsMap[expense.vendorId] ?? 'Unknown',
                ),

              if (expense.categoryId != null)
                _detailRow(
                  FluentIcons.tag,
                  'Category',
                  categoriesMap[expense.categoryId] ?? 'Unknown',
                ),

              if (expense.paymentMode != null &&
                  expense.paymentMode!.isNotEmpty)
                _detailRow(
                  FluentIcons.payment_card,
                  'Payment Mode',
                  expense.paymentMode!,
                ),

              if (expense.billNumber != null && expense.billNumber!.isNotEmpty)
                _detailRow(
                  FluentIcons.receipt_processing,
                  'Bill Number',
                  expense.billNumber!,
                ),

              if (expense.remarks != null && expense.remarks!.isNotEmpty)
                _detailRow(FluentIcons.comment, 'Remarks', expense.remarks!),
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
              _showAddEditDialog(expense: expense);
            },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 125, 123, 121),
                  ),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        await displayInfoBar(
          context,
          builder: (context, close) {
            return const InfoBar(
              title: Text('Expense deleted successfully'),
              severity: InfoBarSeverity.success,
            );
          },
        );
      }
    }
  }

  void _showAddEditDialog({Expense? expense}) async {
    final db = ref.read(databaseProvider);
    final sites = await db.getAllSites();
    final vendors = await db.getAllVendors();
    final categories = await db.getAllCategories();

    if (!mounted) return;

    final descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    final amountController = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );
    final billNumberController = TextEditingController(
      text: expense?.billNumber ?? '',
    );
    final remarksController = TextEditingController(
      text: expense?.remarks ?? '',
    );

    int? selectedSiteId = expense?.siteId;
    int? selectedVendorId = expense?.vendorId;
    int? selectedCategoryId = expense?.categoryId;
    DateTime selectedDate = expense?.date ?? DateTime.now();
    String paymentMode = expense?.paymentMode ?? 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ContentDialog(
          constraints: BoxConstraints(
            minWidth: 200,
            maxWidth: MediaQuery.of(context).size.width * 0.4,
          ),
          title: Text(expense == null ? 'Add New Expense' : 'Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLabel(
                  label: 'Site *',
                  child: ComboBox<int>(
                    value: selectedSiteId,
                    placeholder: const Text('Select site'),
                    isExpanded: true,
                    items: sites
                        .map(
                          (site) => ComboBoxItem(
                            value: site.id,
                            child: Text(
                              site.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedSiteId = value),
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
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
                          onChanged: (date) =>
                              setState(() => selectedDate = date),
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
                          isExpanded: true,
                          items: vendors
                              .map(
                                (vendor) => ComboBoxItem(
                                  value: vendor.id,
                                  child: Text(
                                    vendor.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedVendorId = value),
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
                          isExpanded: true,
                          items: categories
                              .map(
                                (cat) => ComboBoxItem(
                                  value: cat.id,
                                  child: Text(
                                    cat.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedCategoryId = value),
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
                          isExpanded: true,
                          items: const [
                            ComboBoxItem(value: 'Cash', child: Text('Cash')),
                            ComboBoxItem(
                              value: 'Cheque',
                              child: Text('Cheque'),
                            ),
                            ComboBoxItem(
                              value: 'Online',
                              child: Text('Online'),
                            ),
                            ComboBoxItem(value: 'UPI', child: Text('UPI')),
                            ComboBoxItem(value: 'Card', child: Text('Card')),
                          ],
                          onChanged: (value) =>
                              setState(() => paymentMode = value ?? 'Cash'),
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
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Save'),
              onPressed: () async {
                if (selectedSiteId == null ||
                    descriptionController.text.trim().isEmpty ||
                    amountController.text.trim().isEmpty) {
                  await displayInfoBar(
                    context,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text('Please fill all required fields'),
                        severity: InfoBarSeverity.warning,
                      );
                    },
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  await displayInfoBar(
                    context,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text('Invalid amount'),
                        severity: InfoBarSeverity.warning,
                      );
                    },
                  );
                  return;
                }

                if (expense == null) {
                  await db.insertExpense(
                    ExpensesCompanion(
                      siteId: drift.Value(selectedSiteId!),
                      vendorId: drift.Value(selectedVendorId),
                      categoryId: drift.Value(selectedCategoryId),
                      description: drift.Value(
                        descriptionController.text.trim(),
                      ),
                      amount: drift.Value(amount),
                      date: drift.Value(selectedDate),
                      paymentMode: drift.Value(paymentMode),
                      billNumber: drift.Value(billNumberController.text.trim()),
                      remarks: drift.Value(remarksController.text.trim()),
                    ),
                  );
                } else {
                  await db
                      .update(db.expenses)
                      .replace(
                        ExpensesCompanion(
                          id: drift.Value(expense.id),
                          siteId: drift.Value(selectedSiteId!),
                          vendorId: drift.Value(selectedVendorId),
                          categoryId: drift.Value(selectedCategoryId),
                          description: drift.Value(
                            descriptionController.text.trim(),
                          ),
                          amount: drift.Value(amount),
                          date: drift.Value(selectedDate),
                          paymentMode: drift.Value(paymentMode),
                          billNumber: drift.Value(
                            billNumberController.text.trim(),
                          ),
                          remarks: drift.Value(remarksController.text.trim()),
                          createdAt: drift.Value(expense.createdAt),
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
                          expense == null ? 'Expense added' : 'Expense updated',
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

  void _clearFilters() {
    ref.read(expenseStartDateProvider.notifier).state = null;
    ref.read(expenseEndDateProvider.notifier).state = null;
    ref.read(expenseVendorFilterProvider.notifier).state = null;
    ref.read(expensePageProvider.notifier).state = 0;
  }

  void _setThisMonth() {
    final now = DateTime.now();
    ref.read(expenseStartDateProvider.notifier).state = DateTime(
      now.year,
      now.month,
      1,
    );
    ref.read(expenseEndDateProvider.notifier).state = DateTime(
      now.year,
      now.month + 1,
      0,
    );
    ref.read(expensePageProvider.notifier).state = 0;
  }

  void _setLastMonth() {
    final now = DateTime.now();
    ref.read(expenseStartDateProvider.notifier).state = DateTime(
      now.year,
      now.month - 1,
      1,
    );
    ref.read(expenseEndDateProvider.notifier).state = DateTime(
      now.year,
      now.month,
      0,
    );
    ref.read(expensePageProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(paginatedExpensesProvider);
    final totalCountAsync = ref.watch(totalExpensesCountProvider);
    final totalAmountAsync = ref.watch(totalExpensesAmountProvider);
    final page = ref.watch(expensePageProvider);
    final pageSize = ref.watch(expensePageSizeProvider);
    final startDate = ref.watch(expenseStartDateProvider);
    final endDate = ref.watch(expenseEndDateProvider);
    final vendorFilter = ref.watch(expenseVendorFilterProvider);

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
      content: CustomScrollView(
        slivers: [
          // Filters Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).micaBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: FluentTheme.of(
                      context,
                    ).resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.filter, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Filters',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      // Date Range Filters
                      SizedBox(
                        width: 160,
                        child: InfoLabel(
                          label: 'Start Date',
                          child: DatePicker(
                            selected: startDate,
                            onChanged: (date) {
                              ref.read(expenseStartDateProvider.notifier).state =
                                  date;
                              ref.read(expensePageProvider.notifier).state = 0;
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: InfoLabel(
                          label: 'End Date',
                          child: DatePicker(
                            selected: endDate,
                            onChanged: (date) {
                              ref.read(expenseEndDateProvider.notifier).state =
                                  date;
                              ref.read(expensePageProvider.notifier).state = 0;
                            },
                          ),
                        ),
                      ),
                  
                      SizedBox(width: 10),
                      // Quick date buttons
                      Button(
                        onPressed: _setThisMonth,
                        child: const Text('This Month'),
                      ),
                  
                      Button(
                        onPressed: _setLastMonth,
                        child: const Text('Last Month'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 30,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.end,
                  
                    children: [
                      // Vendor Filter
                      SizedBox(
                        width: 200,
                        child: FutureBuilder<List<Vendor>>(
                          future: ref.read(databaseProvider).getAllVendors(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final vendors = snapshot.data!;
                            return InfoLabel(
                              label: 'Vendor',
                              child: ComboBox<int?>(
                                value: vendorFilter,
                                placeholder: const Text('All Vendors'),
                                isExpanded: true,
                                items: [
                                  const ComboBoxItem(
                                    value: null,
                                    child: Text('All Vendors'),
                                  ),
                                  ...vendors.map(
                                    (vendor) => ComboBoxItem(
                                      value: vendor.id,
                                      child: Text(
                                        vendor.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  ref
                                          .read(
                                            expenseVendorFilterProvider.notifier,
                                          )
                                          .state =
                                      value;
                                  ref.read(expensePageProvider.notifier).state =
                                      0;
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  
                      Button(
                        onPressed: _clearFilters,
                        style: ButtonStyle(
                          //backgroundColor: WidgetStateProperty.all(Colors.red.light),
                          foregroundColor: WidgetStateProperty.all(
                            Colors.red.lighter,
                          ),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  
                  // Summary
                  if (totalCountAsync.hasValue && totalAmountAsync.hasValue) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FluentIcons.info, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'Showing ${totalCountAsync.value} expenses • Total: ${currencyFormat.format(totalAmountAsync.value)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      
          // Expenses List
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.money, size: 64),
                          SizedBox(height: 16),
                          Text('No expenses found'),
                          SizedBox(height: 8),
                          Text('Try adjusting your filters or add a new expense'),
                        ],
                      ),
                    ),
                  ),
                );
              }
          
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.light.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(FluentIcons.money, color: Colors.orange),
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
                              style: FluentTheme.of(context)
                                  .typography
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(FluentIcons.edit),
                              onPressed: () =>
                                  _showAddEditDialog(expense: expense),
                            ),
                            IconButton(
                              icon: const Icon(FluentIcons.delete),
                              onPressed: () => _showDeleteConfirmation(expense),
                            ),
                          ],
                        ),
                        onPressed: () => _showExpenseDetails(expense),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => SliverToBoxAdapter(
              child: SizedBox(
                  height: 300,
                child: const Center(child: ProgressRing())),
            ),
            error: (error, stack) => SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(
                  child: InfoBar(
                    title: const Text('Error loading expenses'),
                    content: Text(error.toString()),
                    severity: InfoBarSeverity.error,
                  ),
                ),
              ),
            ),
          ),
      
          // Pagination Controls
          if (totalCountAsync.hasValue && totalCountAsync.value! > 0)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: FluentTheme.of(
                        context,
                      ).resources.dividerStrokeColorDefault,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page size selector
                    Row(
                      children: [
                        const Text('Show: '),
                        const SizedBox(width: 8),
                        ComboBox<int>(
                          value: pageSize,
                          items: const [
                            ComboBoxItem(value: 25, child: Text('25')),
                            ComboBoxItem(value: 50, child: Text('50')),
                            ComboBoxItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(expensePageSizeProvider.notifier).state =
                                  value;
                              ref.read(expensePageProvider.notifier).state = 0;
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('per page'),
                      ],
                    ),
                    // Pagination buttons
                    Row(
                      children: [
                        Button(
                          onPressed: page > 0
                              ? () =>
                                    ref.read(expensePageProvider.notifier).state--
                              : null,
                          child: const Icon(FluentIcons.chevron_left, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Page ${page + 1} of ${((totalCountAsync.value! - 1) / pageSize).ceil() + 1}',
                        ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed:
                              (page + 1) * pageSize < totalCountAsync.value!
                              ? () =>
                                    ref.read(expensePageProvider.notifier).state++
                              : null,
                          child: const Icon(FluentIcons.chevron_right, size: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
