import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:irondiary/main.dart';
import 'package:irondiary/database_helper.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('home page has two dropdowns', (tester) async {
    SharedPreferences.setMockInitialValues({'defaultDataPrompted': true});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton), findsNWidgets(2));
  });

  testWidgets('loads saved selections for dropdowns', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseHelper.instance;
    final catId = await db.insertCategory('測試類別');
    final exId = await db.insertExercise(catId, '測試動作1');
    SharedPreferences.setMockInitialValues({
      'selectedCategory': catId,
      'selectedExercise': exId,
      'defaultDataPrompted': true,
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('測試類別'), findsOneWidget);
    expect(find.text('測試動作1'), findsOneWidget);
  });

  test('prevent duplicate categories and exercises', () async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseHelper.instance;
    final catId = await db.insertCategory('測試類別');
    expect(() => db.insertCategory('測試類別'), throwsException);
    await db.insertExercise(catId, '測試動作1');
    expect(() => db.insertExercise(catId, '測試動作1'), throwsException);
    final catId2 = await db.insertCategory('測試類別2');
    await db.insertExercise(catId2, '測試動作2');
    expect(() => db.insertExercise(catId2, '測試動作1'), throwsException);

    // Editing should also reject duplicates
    expect(() => db.updateCategory(catId2, '測試類別'), throwsException);
    final ex2 = await db.insertExercise(catId, '測試動作3');
    expect(() => db.updateExercise(ex2, '測試動作2'), throwsException);
  });
}
