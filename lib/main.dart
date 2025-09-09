import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_helper.dart';
import 'home_page.dart';
import 'screen_util.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'timer_channel',
      initialNotificationTitle: 'IronDiary 計時器',
      initialNotificationContent: '計時中... ',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );

  const bool isDev = bool.fromEnvironment('IS_DEV');
  if (isDev) {
    await _importDevData();
  }
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications
      .initialize(const InitializationSettings(android: androidInit));
  Timer? timer;

  service.on('startTimer').listen((event) {
    timer?.cancel();
    final seconds = event?['seconds'] as int? ?? 0;
    final exercise = event?['exercise'] as String? ?? '';
    final count = event?['count'] as int? ?? 0;
    timer = Timer(Duration(seconds: seconds), () async {
      await notifications.show(
        0,
        'Timer Completion',
        '休息結束，$exercise今天做了$count組',
        const NotificationDetails(
          android: AndroidNotificationDetails('timer_channel', 'Rest Timer'),
        ),
      );
      service.stopSelf();
    });
  });

  service.on('stopTimer').listen((event) {
    timer?.cancel();
    service.stopSelf();
  });
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
