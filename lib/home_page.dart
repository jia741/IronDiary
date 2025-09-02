import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'exercise_settings_page.dart';
import 'report_page.dart';
import 'screen_util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _exercises = [];
  int? _selectedCategory;
  int? _selectedExercise;
  final TextEditingController _repController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  int _timerSeconds = 60;
  bool _loading = true;
  bool _isTiming = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  AudioPlayer? _audioPlayer;

  int _navIndex = 0;
  int reps = 10;
  double weight = 10;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    Future(() async {
      await _loadSettings();
      await _loadData();
      await _checkFirstLaunch();
      await _importTestRecordsIfEmpty();
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _db.getCategories();
    final savedCat = prefs.getInt('selectedCategory');
    int? firstCat = cats.isNotEmpty ? cats.first['id'] as int : null;
    int? catId = savedCat != null && cats.any((c) => c['id'] == savedCat)
        ? savedCat
        : firstCat;

    List<Map<String, dynamic>> exs = [];
    if (catId != null) {
      exs = await _db.getExercises(catId);
    }
    final savedEx = prefs.getInt('selectedExercise');
    int? exId = savedEx != null && exs.any((e) => e['id'] == savedEx)
        ? savedEx
        : (exs.isNotEmpty ? exs.first['id'] as int : null);

    setState(() {
      _categories = cats;
      _selectedCategory = catId;
      _exercises = exs;
      _selectedExercise = exId;
      _loading = false;
    });
    if (exId != null) {
      await _loadLastWorkout(exId);
    } else {
      setState(() {
        reps = 10;
        weight = 10;
        _timerSeconds = 60;
      });
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool('defaultDataPrompted') ?? false;
    if (!prompted) {
      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('匯入預設動作？'),
          content: const Text('是否匯入常見的動作與分類？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('否'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('是'),
            ),
          ],
        ),
      );
      if (shouldImport ?? false) {
        await _importDefaultExercises();
        await _loadData();
      }
      await prefs.setBool('defaultDataPrompted', true);
    }
  }

  Future<void> _importDefaultExercises() async {
    final data = await rootBundle.loadString('assets/default_exercises.json');
    final Map<String, dynamic> jsonMap = json.decode(data);
    final List cats = jsonMap['categories'] as List;
    for (final c in cats) {
      final catName = c['name'] as String;
      final catId = await _db.insertCategory(catName);
      final List exs = c['exercises'] as List;
      for (final e in exs) {
        await _db.insertExercise(catId, e as String);
      }
    }
  }

  Future<void> _importTestRecordsIfEmpty() async {
    final db = await _db.database;
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM workouts')) ?? 0;
    if (count > 0) return;
    final data = await rootBundle.loadString('assets/test_records.json');
    final Map<String, dynamic> jsonMap = json.decode(data);
    final List records = jsonMap['records'] as List;
    final Map<String, int> categoryIds = {};
    final Map<String, int> exerciseIds = {};
    for (final r in records) {
      final date = DateTime.parse(r['date'] as String);
      final List wos = r['workouts'] as List;
      for (final w in wos) {
        final catName = w['category'] as String;
        int catId;
        if (categoryIds.containsKey(catName)) {
          catId = categoryIds[catName]!;
        } else {
          final existingCat = await db.query('categories',
              where: 'name = ?', whereArgs: [catName]);
          if (existingCat.isNotEmpty) {
            catId = existingCat.first['id'] as int;
          } else {
            catId = await _db.insertCategory(catName);
          }
          categoryIds[catName] = catId;
        }

        final exName = w['exercise'] as String;
        final exKey = '$catId-$exName';
        int exId;
        if (exerciseIds.containsKey(exKey)) {
          exId = exerciseIds[exKey]!;
        } else {
          final existingEx = await db.query('exercises',
              where: 'name = ? AND category_id = ?',
              whereArgs: [exName, catId]);
          if (existingEx.isNotEmpty) {
            exId = existingEx.first['id'] as int;
          } else {
            exId = await _db.insertExercise(catId, exName);
          }
          exerciseIds[exKey] = exId;
        }

        await db.insert('workouts', {
          'exercise_id': exId,
          'reps': w['reps'] as int,
          'weight': (w['weight'] as num).toDouble(),
          'unit': w['unit'] as String,
          'rest_seconds': w['rest_seconds'] as int,
          'timestamp': date.millisecondsSinceEpoch,
        });
      }
    }
    await _loadData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weightUnit = prefs.getString('weightUnit') ?? _weightUnit;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('timerSeconds', _timerSeconds);
    await prefs.setInt('reps', reps);
    await prefs.setDouble('weight', weight);
    await prefs.setString('weightUnit', _weightUnit);
    if (_selectedCategory != null) {
      await prefs.setInt('selectedCategory', _selectedCategory!);
    }
    if (_selectedExercise != null) {
      await prefs.setInt('selectedExercise', _selectedExercise!);
    }
  }

  @override
  void dispose() {
    _repController.dispose();
    _weightController.dispose();
    _timer?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _onCategoryChanged(int? id) async {
    if (id == null) return;
    final exs = await _db.getExercises(id);
    setState(() {
      _selectedCategory = id;
      _exercises = exs;
      _selectedExercise = exs.isNotEmpty ? exs.first['id'] as int : null;
    });
    if (_selectedExercise != null) {
      await _loadLastWorkout(_selectedExercise!);
    } else {
      setState(() {
        reps = 10;
        weight = 10;
        _timerSeconds = 60;
      });
    }
    unawaited(_saveSettings());
  }

  Future<void> _startWorkout() async {
    final exId = _selectedExercise;
    //final reps = int.tryParse(_repController.text);
    //final weight = double.tryParse(_weightController.text);
    if (exId == null) return;
    await _db.logWorkout(exId, reps, weight, _weightUnit, _timerSeconds);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('開始計時')));
    setState(() {
      _isTiming = true;
      _remainingSeconds = _timerSeconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        if (!mounted) return;
        _audioPlayer ??= AudioPlayer();
        unawaited(_audioPlayer!.play(AssetSource('readytowork.mp3')));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('計時完成')));
        setState(() {
          _isTiming = false;
        });
      }
    });
  }

  void _toggleWeightUnit() {
    setState(() {
      if (_weightUnit == 'kg') {
        weight = weight * 2.20462;
        _weightUnit = 'lb';
      } else {
        weight = weight / 2.20462;
        _weightUnit = 'kg';
      }
    });
    unawaited(_saveSettings());
  }

  Future<void> _loadLastWorkout(int exerciseId) async {
    final data = await _db.getLastWorkout(exerciseId);
    setState(() {
      if (data != null) {
        reps = data['reps'] as int;
        weight = (data['weight'] as num).toDouble();
        _weightUnit = data['unit'] as String;
        _timerSeconds = data['rest_seconds'] as int;
      } else {
        reps = 10;
        weight = 10;
        _weightUnit = 'kg';
        _timerSeconds = 60;
      }
    });
    unawaited(_saveSettings());
  }

  void _showTimerDialog() {
    final controller = TextEditingController(text: _timerSeconds.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('設定組間休息秒數'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _timerSeconds =
                      int.tryParse(controller.text) ?? _timerSeconds;
                });
                unawaited(_saveSettings());
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())));
    }

    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isTiming,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ScreenUtil.w(20)),
            child: Column(
              children: [
                SizedBox(height: ScreenUtil.h(20)),
                // 美化下拉 1：部位
                prettyDropdown<int>(
                  context: context,
                  label: '部位',
                  value: _selectedCategory,
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(
                            c['name'] as String,
                            style: TextStyle(
                              fontSize: ScreenUtil.w(16),
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onCategoryChanged,
                ),

                SizedBox(height: ScreenUtil.h(12)),
                // 美化下拉 2：動作
                prettyDropdown<int>(
                  context: context,
                  label: '動作',
                  value: _selectedExercise,
                  items: _exercises
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as int,
                          child: Text(
                            e['name'] as String,
                            style: TextStyle(
                              fontSize: ScreenUtil.w(16),
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() => _selectedExercise = id);
                    if (id != null) {
                      unawaited(_loadLastWorkout(id));
                    } else {
                      setState(() {
                        reps = 10;
                        weight = 10;
                        _timerSeconds = 60;
                      });
                      unawaited(_saveSettings());
                    }
                  },
                ),
                SizedBox(height: ScreenUtil.h(16)),

                // 數值列：左右留白已由外層 padding 提供
                NumberRow(
                  label: '次數',
                  labelTrailing: SizedBox(width: ScreenUtil.w(64)),
                  valueText: reps.toString(),
                  onMinus: () {
                    setState(() => reps = (reps - 1).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onPlus: () {
                    setState(() => reps = (reps + 1).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onSubmitted: (v) {
                    setState(() => reps = int.tryParse(v) ?? reps);
                    unawaited(_saveSettings());
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: ScreenUtil.h(12)),
                NumberRow(
                  label: '重量',
                  labelTrailing: OutlinedButton(
                    onPressed: _toggleWeightUnit,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      //minimumSize: Size(ScreenUtil.w(36), ScreenUtil.w(36)),
                    ),
                    child: Text(_weightUnit),
                  ),
                  valueText: weight.toStringAsFixed(1),
                  onMinus: () {
                    setState(() =>
                        weight = double.parse(((weight - 0.1).clamp(0, 999))
                            .toStringAsFixed(1)));
                    unawaited(_saveSettings());
                  },
                  onPlus: () {
                    setState(() =>
                        weight = double.parse(((weight + 0.1).clamp(0, 999))
                            .toStringAsFixed(1)));
                    unawaited(_saveSettings());
                  },
                  onSubmitted: (v) {
                    setState(() => weight = double.tryParse(v) ?? weight);
                    unawaited(_saveSettings());
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,1}'),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _isTiming ? null : _startWorkout,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        minimumSize: Size.square(ScreenUtil.w(100)),
                      ),
                      child: Text(_isTiming ? '$_remainingSeconds' : '開始'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(indicatorColor: Colors.transparent),
        child: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) => setState(() {
            _navIndex = i;
            switch (i) {
              case 0:
                _showTimerDialog();
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportPage()),
                );
                break;
              case 2:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExerciseSettingsPage(),
                  ),
                ).then((_) => _loadData());
                break;
            }
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.timer), label: '計時'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '報表'),
            NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
          ],
        ),
      ),
    );
  }
}

// 下拉樣式（M3 外觀）
Widget prettyDropdown<T>({
  required BuildContext context,
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    style: TextStyle(fontSize: ScreenUtil.w(16)),
    items: items,
    onChanged: onChanged,
    icon: Icon(Icons.keyboard_arrow_down_rounded, size: ScreenUtil.w(24)),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      contentPadding: EdgeInsets.symmetric(
        horizontal: ScreenUtil.w(16),
        vertical: ScreenUtil.h(14),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ScreenUtil.w(16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ScreenUtil.w(16)),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
    ),
  );
}

/// 含 +/- 與可輸入的數值列
class NumberRow extends StatefulWidget {
  const NumberRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
    required this.onSubmitted,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.labelTrailing,
  });

  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSubmitted;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? labelTrailing;

  @override
  State<NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<NumberRow> {
  late final TextEditingController _c = TextEditingController(
    text: widget.valueText,
  );

  Timer? _repeatTimer;
  Duration _repeatDuration = const Duration(milliseconds: 500);
  VoidCallback? _repeatAction;

  @override
  void didUpdateWidget(covariant NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueText != widget.valueText) {
      _c.text = widget.valueText;
      _c.selection = TextSelection.fromPosition(
        TextPosition(offset: _c.text.length),
      );
    }
  }

  void _startRepeat(VoidCallback action) {
    _repeatAction = action;
    action();
    _repeatDuration = const Duration(milliseconds: 500);
    _repeatTimer?.cancel();
    _repeatTimer = Timer(_repeatDuration, _onRepeat);
  }

  void _onRepeat() {
    final act = _repeatAction;
    if (act == null) return;
    act();
    var ms = (_repeatDuration.inMilliseconds * 0.8).toInt();
    if (ms < 50) ms = 50;
    _repeatDuration = Duration(milliseconds: ms);
    _repeatTimer = Timer(_repeatDuration, _onRepeat);
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatAction = null;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ScreenUtil.w(8)),
        child: Row(
          children: [
            SizedBox(width: ScreenUtil.w(8)),
            Flexible(
              flex: 1,
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: ScreenUtil.w(16),
                    ),
                  ),
                  if (widget.labelTrailing != null) ...[
                    SizedBox(width: ScreenUtil.w(8)),
                    widget.labelTrailing!,
                    SizedBox(width: ScreenUtil.w(8)),
                  ],
                ],
              ),
            ),
            Flexible(
              flex: 1,
              child: Row(
                children: [
                  Flexible(
                    child: Listener(
                      onPointerDown: (_) => _startRepeat(widget.onMinus),
                      onPointerUp: (_) => _stopRepeat(),
                      onPointerCancel: (_) => _stopRepeat(),
                      child: IconButton(
                        onPressed: () {},
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(100)),
                            side: BorderSide(width: 1),
                          ),
                        ),
                        icon: Icon(Icons.remove, size: ScreenUtil.w(16)),
                      ),
                    ),
                  ),
                  SizedBox(width: ScreenUtil.w(8)),
                  Flexible(
                    child: TextField(
                      controller: _c,
                      textAlign: TextAlign.center,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      onSubmitted: widget.onSubmitted,
                      style: TextStyle(fontSize: ScreenUtil.w(16)),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  SizedBox(width: ScreenUtil.w(8)),
                  Flexible(
                    child: Listener(
                      onPointerDown: (_) => _startRepeat(widget.onPlus),
                      onPointerUp: (_) => _stopRepeat(),
                      onPointerCancel: (_) => _stopRepeat(),
                      child: IconButton(
                        onPressed: () {},
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(100)),
                            side: BorderSide(width: 1),
                          ),
                        ),
                        icon: Icon(Icons.add, size: ScreenUtil.w(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
