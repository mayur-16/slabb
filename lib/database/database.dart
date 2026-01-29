import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Sites Table
class Sites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Vendors Table
class Vendors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Expense Categories Table
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
}

// Expenses Table
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get siteId => integer().references(Sites, #id)();
  IntColumn get vendorId => integer().nullable().references(Vendors, #id)();
  IntColumn get categoryId => integer().nullable().references(ExpenseCategories, #id)();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get paymentMode => text().nullable()(); // Cash, Cheque, Online, etc.
  TextColumn get billNumber => text().nullable()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Sites, Vendors, ExpenseCategories, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Sites Operations
  Future<List<Site>> getAllSites() => select(sites).get();
  
  Future<int> insertSite(SitesCompanion site) => into(sites).insert(site);
  Future<int> deleteSite(int id) => (delete(sites)..where((s) => s.id.equals(id))).go();

  // Vendors Operations
  Future<List<Vendor>> getAllVendors() => select(vendors).get();
  Future<int> insertVendor(VendorsCompanion vendor) => into(vendors).insert(vendor);
  Future<int> deleteVendor(int id) => (delete(vendors)..where((v) => v.id.equals(id))).go();

  // Categories Operations
  Future<List<ExpenseCategory>> getAllCategories() => select(expenseCategories).get();
  Future<int> insertCategory(ExpenseCategoriesCompanion category) => 
    into(expenseCategories).insert(category);
  Future<int> deleteCategory(int id) => 
    (delete(expenseCategories)..where((c) => c.id.equals(id))).go();

  // Expenses Operations
  Future<List<Expense>> getAllExpenses() => select(expenses).get();
  
  Future<List<Expense>> getExpensesBySite(int siteId) => 
    (select(expenses)..where((e) => e.siteId.equals(siteId))).get();
  
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) => 
    (select(expenses)..where((e) => e.date.isBetweenValues(start, end))).get();
  
  Future<int> insertExpense(ExpensesCompanion expense) => into(expenses).insert(expense);
  Future<int> deleteExpense(int id) => (delete(expenses)..where((e) => e.id.equals(id))).go();

  // Aggregations
  Future<double> getTotalExpensesBySite(int siteId) async {
    final query = selectOnly(expenses)
      ..addColumns([expenses.amount.sum()])
      ..where(expenses.siteId.equals(siteId));
    
    final result = await query.getSingle();
    return result.read(expenses.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalExpenses() async {
    final query = selectOnly(expenses)..addColumns([expenses.amount.sum()]);
    final result = await query.getSingle();
    return result.read(expenses.amount.sum()) ?? 0.0;
  }

  // Bulk Import
  Future<void> bulkInsertVendors(List<VendorsCompanion> vendorsList) async {
    await batch((batch) {
      batch.insertAll(vendors, vendorsList);
    });
  }

  Future<void> bulkInsertExpenses(List<ExpensesCompanion> expensesList) async {
    await batch((batch) {
      batch.insertAll(expenses, expensesList);
    });
  }

  // Initialize default categories
  Future<void> initializeDefaultCategories() async {
    final existing = await getAllCategories();
    if (existing.isEmpty) {
      final defaultCategories = [
        'Materials',
        'Labour',
        'Equipment Rental',
        'Transportation',
        'Utilities',
        'Permits & Fees',
        'Miscellaneous',
      ];

      for (final category in defaultCategories) {
        await insertCategory(ExpenseCategoriesCompanion.insert(name: category));
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ConstructionExpenses', 'expenses.db'));
    
    // Create directory if it doesn't exist
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    
    return NativeDatabase(file);
  });
}