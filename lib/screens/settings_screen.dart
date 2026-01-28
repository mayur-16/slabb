import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../database/database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _downloadVendorTemplate(BuildContext context) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Vendor Template',
        fileName: 'vendor_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      const templateContent = 'Name,Contact Person,Phone,Email,Address\n'
          'ABC Suppliers,John Doe,9876543210,john@abc.com,123 Main Street\n'
          'XYZ Hardware,Jane Smith,9876543211,jane@xyz.com,456 Oak Avenue';

      final file = File(result);
      await file.writeAsString(templateContent);

      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Template downloaded successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Download failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _openDatabaseLocation(BuildContext context) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'ConstructionExpenses');
      
      if (Platform.isMacOS) {
        await Process.run('open', [dbPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dbPath]);
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Failed to open location'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _backupDatabase(BuildContext context, WidgetRef ref) async {
    try {
      // Get the database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'ConstructionExpenses', 'expenses.db'));

      if (!await dbFile.exists()) {
        if (context.mounted) {
          await displayInfoBar(context, builder: (context, close) {
            return const InfoBar(
              title: Text('No database found'),
              severity: InfoBarSeverity.error,
            );
          });
        }
        return;
      }

      // Let user choose save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: 'construction_expenses_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null) return;

      // Copy database file to chosen location
      await dbFile.copy(result);

      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Backup created successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Backup failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _restoreDatabase(BuildContext context, WidgetRef ref) async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Backup File',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result == null || result.files.single.path == null) return;

      final backupFile = File(result.files.single.path!);

      // Verify backup file exists and is valid
      if (!await backupFile.exists()) {
        if (context.mounted) {
          await displayInfoBar(context, builder: (context, close) {
            return const InfoBar(
              title: Text('Backup file not found'),
              severity: InfoBarSeverity.error,
            );
          });
        }
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'This will replace all current data with the backup. The app will close automatically after restore. Continue?',
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            FilledButton(
              child: const Text('Restore & Close App'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Get database location
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'ConstructionExpenses', 'expenses.db'));

      // Close database connection with timeout to prevent hanging
      final db = ref.read(databaseProvider);
      try {
        await db.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            // If close hangs, just continue - the file copy will force close it
            debugPrint('Database close timed out, continuing anyway');
          },
        );
      } catch (e) {
        debugPrint('Error closing database: $e, continuing anyway');
      }

      // Wait for file handles to be released
      await Future.delayed(const Duration(milliseconds: 500));

      // Copy backup to database location (this will overwrite even if db is still open)
      await backupFile.copy(dbFile.path);

      if (!context.mounted) return;

      // Show success message
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ContentDialog(
          title: const Text('Restore Successful'),
          content: const Text(
            'Backup has been restored successfully.\n\nThe application will now close. Please restart it to see the restored data.',
          ),
          actions: [
            FilledButton(
              child: const Text('Close App'),
              onPressed: () {
                exit(0);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Restore failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _importVendorsCSV(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Vendors CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      final csvData = const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty) {
        if (context.mounted) {
          await displayInfoBar(context, builder: (context, close) {
            return const InfoBar(
              title: Text('CSV file is empty'),
              severity: InfoBarSeverity.warning,
            );
          });
        }
        return;
      }

      // Expected format: Name, Contact Person, Phone, Email, Address
      final vendors = <VendorsCompanion>[];
      
      // Skip header row
      for (var i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.isEmpty) continue;

        vendors.add(VendorsCompanion(
          name: drift.Value(row[0].toString().trim()),
          contactPerson: drift.Value(row.length > 1 ? row[1].toString().trim() : ''),
          phone: drift.Value(row.length > 2 ? row[2].toString().trim() : ''),
          email: drift.Value(row.length > 3 ? row[3].toString().trim() : ''),
          address: drift.Value(row.length > 4 ? row[4].toString().trim() : ''),
        ));
      }

      if (vendors.isEmpty) {
        if (context.mounted) {
          await displayInfoBar(context, builder: (context, close) {
            return const InfoBar(
              title: Text('No valid vendor data found'),
              severity: InfoBarSeverity.warning,
            );
          });
        }
        return;
      }

      final db = ref.read(databaseProvider);
      await db.bulkInsertVendors(vendors);

      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('${vendors.length} vendors imported successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Import failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _exportToCSV(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final expenses = await db.getAllExpenses();
      final sites = await db.getAllSites();
      final vendors = await db.getAllVendors();
      final categories = await db.getAllCategories();

      // Create lookups
      final sitesMap = {for (var s in sites) s.id: s.name};
      final vendorsMap = {for (var v in vendors) v.id: v.name};
      final categoriesMap = {for (var c in categories) c.id: c.name};

      // Prepare CSV data
      final csvData = [
        ['Date', 'Site', 'Description', 'Category', 'Vendor', 'Amount', 'Payment Mode', 'Bill Number', 'Remarks'],
        ...expenses.map((e) => [
          DateFormat('dd/MM/yyyy').format(e.date),
          sitesMap[e.siteId] ?? '',
          e.description,
          e.categoryId != null ? categoriesMap[e.categoryId] ?? '' : '',
          e.vendorId != null ? vendorsMap[e.vendorId] ?? '' : '',
          e.amount.toString(),
          e.paymentMode ?? '',
          e.billNumber ?? '',
          e.remarks ?? '',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(csvData);

      // Let user choose save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Expenses',
        fileName: 'expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      // Write to file
      final file = File(result);
      await file.writeAsString(csv);

      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return const InfoBar(
            title: Text('Expenses exported successfully'),
            severity: InfoBarSeverity.success,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: const Text('Export failed'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }
  }

  Future<void> _showDatabaseLocation(BuildContext context) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'ConstructionExpenses', 'expenses.db');

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Database Location'),
          content: SelectableText(dbPath),
          actions: [
            FilledButton(
              child: const Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage(
      header: const PageHeader(
        title: Text('Settings'),
      ),
      content: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Backup & Restore
          Text(
            'Backup & Restore',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(FluentIcons.database),
                  title: const Text('Backup Database'),
                  subtitle: const Text('Save a copy of your data'),
                  trailing: Button(
                    child: const Text('Backup'),
                    onPressed: () => _backupDatabase(context, ref),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(FluentIcons.sync),
                  title: const Text('Restore Database'),
                  subtitle: const Text('Restore from a backup file'),
                  trailing: Button(
                    child: const Text('Restore'),
                    onPressed: () => _restoreDatabase(context, ref),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Import & Export
          Text(
            'Import & Export',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 16),
          Card(
                          child: Column(
              children: [
                ListTile(
                  leading: const Icon(FluentIcons.import),
                  title: const Text('Import Vendors'),
                  subtitle: const Text('Import vendors from CSV (Name, Contact, Phone, Email, Address)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        child: const Text('Download Template'),
                        onPressed: () => _downloadVendorTemplate(context),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('Import CSV'),
                        onPressed: () => _importVendorsCSV(context, ref),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(FluentIcons.export),
                  title: const Text('Export Expenses'),
                  subtitle: const Text('Export all expenses to CSV'),
                  trailing: Button(
                    child: const Text('Export CSV'),
                    onPressed: () => _exportToCSV(context, ref),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Information
          Text(
            'Information',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(FluentIcons.database),
                  title: const Text('Database Location'),
                  subtitle: const Text('View where your data is stored'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        child: const Text('Show Path'),
                        onPressed: () => _showDatabaseLocation(context),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('Open Folder'),
                        onPressed: () => _openDatabaseLocation(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(FluentIcons.info),
                  title: Text('Version'),
                  trailing: Text('v1.0.0'),
                ),
              ],
            ),
          ),

const SizedBox(height: 32),


           // Branding Footer
           Text(
            'About Us',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/icon/wallet.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(FluentIcons.processing, size: 64);
                    },
                  ),
                 
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Developed by Tequra Solutions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(FluentIcons.mail, size: 14),
                      const SizedBox(width: 6),
                      HyperlinkButton(
                        onPressed: () async {
                          // Open email client
                          final Uri emailUri = Uri(
                            scheme: 'mailto',
                            path: 'mayur.acharya.contact@gmail.com',
                            query: 'subject=Slabb Support',
                          );
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          }
                        },
                        child: const Text(
                          'mayur.acharya.contact@gmail.com',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(FluentIcons.globe, size: 14),
                      const SizedBox(width: 6),
                      HyperlinkButton(
                        onPressed: () async {
                          final Uri url = Uri.parse('https://mayur-16.github.io/portfolio');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: const Text(
                          'Developer Portfolio',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                         
                ],
              ),
            ),
          ),
 const SizedBox(height: 20),
           Center(
                    child: Text(
                      '© ${DateTime.now().year} Tequra Solutions. All rights reserved.',
                      style:  TextStyle(fontSize: 10,),
                      textAlign: TextAlign.center,
                    ),
                  ),
        ],
      ),
    );
  }
}