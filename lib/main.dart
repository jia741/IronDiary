import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'home_page.dart';
import 'screen_util.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const bool isDev = bool.fromEnvironment('IS_DEV');
  if (isDev) {
    await _importDevData();
  }
  runApp(const MyApp());
}

Future<void> _importDevData() async {
  final db = DatabaseHelper.instance;
  await db.clearAll();

  final defaultJson =
      await rootBundle.loadString('assets/default_exercises.json');
  final defaultData = jsonDecode(defaultJson) as Map<String, dynamic>;

  final Map<String, int> exerciseIds = {};
  for (final category in defaultData['categories'] as List<dynamic>) {
    final categoryId = await db.insertCategory(category['name'] as String);
    for (final exercise in category['exercises'] as List<dynamic>) {
      final name = exercise as String;
      final exerciseId = await db.insertExercise(categoryId, name);
      exerciseIds[name] = exerciseId;
    }
  }

  final recordsJson = await rootBundle.loadString('assets/test_records.json');
  final recordsData = jsonDecode(recordsJson) as Map<String, dynamic>;
  for (final record in recordsData['records'] as List<dynamic>) {
    final date = DateTime.parse(record['date'] as String);
    for (final workout in record['workouts'] as List<dynamic>) {
      final exerciseId = exerciseIds[workout['exercise'] as String];
      if (exerciseId == null) continue;
      await db.logWorkout(
        exerciseId,
        workout['reps'] as int,
        (workout['weight'] as num).toDouble(),
        workout['unit'] as String,
        workout['rest_seconds'] as int,
        timestamp: date,
      );
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = Colors.blue;
    return MaterialApp(
      builder: (context, child) {
        ScreenUtil.init(context);
        return child!;
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
