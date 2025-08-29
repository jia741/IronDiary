import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:irondiary/main.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('home page has two dropdowns', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton), findsNWidgets(2));
  });

  testWidgets('loads saved selections for dropdowns', (tester) async {
    SharedPreferences.setMockInitialValues({
      'selectedCategory': 2,
      'selectedExercise': 7,
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('肩'), findsOneWidget);
    expect(find.text('槓鈴肩推'), findsOneWidget);
  });
}
