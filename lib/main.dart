import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database.dart';
import 'screens/home_screen.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final db = AppDatabase();
  await db.initializeDefaultCategories();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Slabb',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.light,
        accentColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}