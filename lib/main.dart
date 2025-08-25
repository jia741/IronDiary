import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.blue;
    final lightScheme =
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    final darkScheme =
        ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);
    return MaterialApp(
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
